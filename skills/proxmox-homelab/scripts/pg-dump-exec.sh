#!/bin/bash
# Nightly consistent pg_dump of app Postgres DBs that tiredofit db-backup does not cover.
# Runs from TrueNAS cron 02:30 as root. Uses `docker exec` + local socket inside each app's postgres container,
# so no passwords, no extra Docker networks, no change to db-backup. Output layout matches db-backup
# (pgsql_<db>_<container>_<ts>.sql.zst + .sha1 + latest-* symlink, apps:apps 0600, 30-day cleanup) in
# ${OUT:-/mnt/<apps-pool>/Applications/db-dumps}/<app>/, which an off-site Backrest/restic plan must include.
# See references/backup-health.md section 6 (consistent DB dumps).
set -u -o pipefail
OUT=${OUT:-/mnt/<apps-pool>/Applications/db-dumps}
KEEP_DAYS=30
JOBS=${JOBS:?set JOBS="name:container name2:container2"}
rc=0
log() { logger -t labby-pgdump "$*"; echo "$(date '+%F %T') $*"; }
for spec in $JOBS; do
  name=${spec%%:*}; c=${spec#*:}; dir=$OUT/$name
  install -d -o apps -g apps -m 700 "$dir"
  db=$(docker exec "$c" printenv POSTGRES_DB 2>/dev/null) || { log "$name: container $c not running"; rc=1; continue; }
  base=pgsql_${db}_${c}_$(date +%Y%m%d-%H%M%S).sql.zst; f=$dir/$base; tmp=$dir/.$base.partial
  if timeout 1200 docker exec "$c" sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-password' | zstd -q -10 -T0 -o "$tmp" -f \
     && zstd -q -t "$tmp" && [ "$(stat -c %s "$tmp")" -gt 1000 ] \
     && zstd -dc "$tmp" | tail -c 200 | grep -q "PostgreSQL database dump complete"; then
    mv "$tmp" "$f"; (cd "$dir" && sha1sum "$base" > "$base.sha1")
    ln -sfn "$base" "$dir/latest-pgsql_${db}_${c}"
    chown -h apps:apps "$f" "$f.sha1" "$dir/latest-pgsql_${db}_${c}"; chmod 600 "$f" "$f.sha1"
    find "$dir" -maxdepth 1 -type f -name "pgsql_${db}_${c}_*.sql.zst*" -mtime +$KEEP_DAYS -delete
    log "$name: ok $base $(stat -c %s "$f") B"
  else
    rm -f "$tmp"; log "$name: FAILED dump of $c"; rc=1
  fi
done
exit $rc
