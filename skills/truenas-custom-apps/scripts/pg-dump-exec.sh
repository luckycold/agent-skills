#!/bin/bash
# Nightly consistent pg_dump of app Postgres DBs that tiredofit db-backup does not cover, plus a password-less roles dump
# per DB and optional tars of app file dirs the backup reader cannot open itself.
# Run from TrueNAS cron as root, after db-backup and before the Backrest runs. `docker exec` + local socket: no passwords,
# no extra Docker networks. Layout matches db-backup (pgsql_<db>_<container>_<ts>.sql.zst + .sha1 + latest-*, uid 568, 0600)
# in $OUT/<app>/, which an off-site Backrest/restic plan must include.
# Cleanup is MANIFEST-BASED: only files this script wrote (<dir>/.labby-pgdump.manifest) are deleted after KEEP_DAYS.
# Never glob-delete in a shared dump folder (a glob cleanup once removed older dumps another tool had written).
# See proxmox-homelab/references/backup-health.md section 6 (consistent DB dumps).
set -u -o pipefail
OUT=${OUT:-/mnt/<apps-pool>/Applications/db-dumps}
KEEP_DAYS=30
JOBS=${JOBS:-"<app>:ix-<app>-postgres-1"}   # app:container ...
# app:source-dir tarred next to the dump (Backrest runs as uid 568 and cannot read these root-0770 dirs itself)
TARS=${TARS:-""}   # app:/abs/dir ... (root-only dirs the backup reader cannot open)
rc=0
log() { logger -t labby-pgdump "$*"; echo "$(date '+%F %T') $*"; }
finish() { # dir base -> sha1, perms, manifest
  (cd "$1" && sha1sum "$2" > "$2.sha1"); chown apps:apps "$1/$2" "$1/$2.sha1"; chmod 600 "$1/$2" "$1/$2.sha1"
  echo "$2" >> "$1/.labby-pgdump.manifest"; chown apps:apps "$1/.labby-pgdump.manifest"; chmod 600 "$1/.labby-pgdump.manifest"; }
cleanup() { # dir: delete only manifest-listed files older than KEEP_DAYS
  local m=$1/.labby-pgdump.manifest keep=() b
  [ -f "$m" ] || return 0
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    case "$b" in */*|.*) keep+=("$b"); continue;; esac   # never follow odd names
    if [ -f "$1/$b" ] && [ -n "$(find "$1/$b" -maxdepth 0 -mtime +$KEEP_DAYS)" ]; then
      rm -f -- "$1/$b" "$1/$b.sha1"; log "$(basename "$1"): expired $b"
    elif [ -e "$1/$b" ]; then keep+=("$b"); fi
  done < "$m"
  printf '%s\n' "${keep[@]}" | sort -u | sed '/^$/d' > "$m.tmp" && mv "$m.tmp" "$m"; chown apps:apps "$m"; chmod 600 "$m"; }
ts=$(date +%Y%m%d-%H%M%S)
for spec in $JOBS; do
  name=${spec%%:*}; c=${spec#*:}; dir=$OUT/$name
  install -d -o apps -g apps -m 700 "$dir"
  db=$(docker exec "$c" printenv POSTGRES_DB 2>/dev/null) || { log "$name: container $c not running"; rc=1; continue; }
  base=pgsql_${db}_${c}_${ts}.sql.zst; f=$dir/$base; tmp=$dir/.$base.partial
  if timeout 1200 docker exec "$c" sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-password' | zstd -q -10 -T0 -o "$tmp" -f \
     && zstd -q -t "$tmp" && [ "$(stat -c %s "$tmp")" -gt 1000 ] \
     && zstd -dc "$tmp" | tail -c 200 | grep -q "PostgreSQL database dump complete"; then
    mv "$tmp" "$f"; finish "$dir" "$base"
    ln -sfn "$base" "$dir/latest-pgsql_${db}_${c}"; chown -h apps:apps "$dir/latest-pgsql_${db}_${c}"
    log "$name: ok $base $(stat -c %s "$f") B"
    # roles (globals) without passwords: pg_dump has no CREATE ROLE, and some apps own objects with extra roles (e.g. an app-created admin role)
    rb=roles_${db}_${c}_${ts}.sql.zst; rt=$dir/.$rb.partial
    if docker exec "$c" sh -c 'pg_dumpall -U "$POSTGRES_USER" --roles-only --no-role-passwords' | zstd -q -10 -o "$rt" -f \
       && zstd -dc "$rt" | grep -q "PostgreSQL database cluster dump complete"; then
      mv "$rt" "$dir/$rb"; finish "$dir" "$rb"
    else rm -f "$rt"; log "$name: FAILED roles dump of $c"; rc=1; fi
  else
    rm -f "$tmp"; log "$name: FAILED dump of $c"; rc=1
  fi
  cleanup "$dir"
done
for t in $TARS; do
  name=${t%%:*}; src=${t#*:}; dir=$OUT/$name; base=files_${name}_${ts}.tar.zst; tmp=$dir/.$base.partial
  install -d -o apps -g apps -m 700 "$dir"
  if [ -d "$src" ] && tar -C "$(dirname "$src")" -cf - "$(basename "$src")" | zstd -q -10 -T0 -o "$tmp" -f && zstd -q -t "$tmp"; then
    mv "$tmp" "$dir/$base"; finish "$dir" "$base"; ln -sfn "$base" "$dir/latest-files_${name}"; chown -h apps:apps "$dir/latest-files_${name}"
    log "$name: ok $base $(stat -c %s "$dir/$base") B"
  else rm -f "$tmp"; log "$name: FAILED tar of $src"; rc=1; fi
  cleanup "$dir"
done
exit $rc
