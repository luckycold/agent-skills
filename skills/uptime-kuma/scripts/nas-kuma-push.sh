#!/bin/bash
# Labby: read-only health checks on TrueNAS, pushed to Uptime Kuma (Proxmox CT). Runs every 5 min from TrueNAS cron.
# Additive only: never changes app/pool state. Tokens live in ./tokens.env (root 600). Docs: private notes
set -u
DIR=$(cd "$(dirname "$0")" && pwd); . "$DIR/tokens.env"
KUMA=${KUMA:-http://<kuma-ip>:3001}
EXPECTED_STOPPED=${EXPECTED_STOPPED:-"romm sync bookshelf"}   # intentionally stopped apps (Luke)
now=$(date +%s)
push() { # key status msg
  local tok=${!1:-}; [ -z "$tok" ] && return
  curl -fsS -m 10 -G "$KUMA/api/push/$tok" --data-urlencode "status=$2" --data-urlencode "msg=${3:0:250}" -o /dev/null || echo "push $1 failed" >&2
}
age_h() { echo $(( (now - $(stat -c %Y "$1")) / 3600 )); }

# ZFS pools
zx=$(zpool status -x 2>&1); caps=$(zpool list -H -o name,cap | awk '{printf "%s %s ",$1,$2}')
hi=$(zpool list -H -o name,cap | tr -d % | awk '$2>=90{print $1"="$2"%"}' | xargs)
if [ "$zx" = "all pools are healthy" ] && [ -z "$hi" ]; then push T_NAS_ZFS up "healthy; $caps"; else push T_NAS_ZFS down "${hi:+full: $hi; }$(echo "$zx" | head -3 | tr '\n' ' ')"; fi

# Apps state
bad=$(midclt call app.query '[]' '{"select":["name","state"]}' | EXP="$EXPECTED_STOPPED" python3 -c '
import json,os,sys
exp=set(os.environ["EXP"].split())
print(" ".join(a["name"]+"="+a["state"] for a in json.load(sys.stdin) if a["name"] not in exp and a["state"]!="RUNNING"))' 2>&1) || bad="check-failed"
[ -z "$bad" ] && push T_NAS_APPS up "all apps RUNNING (paused by design: $EXPECTED_STOPPED)" || push T_NAS_APPS down "not running: $bad"

# Containers health / restart loops
unh=$(docker ps --filter health=unhealthy --format '{{.Names}}' | xargs)
rst=$(docker ps -a --filter status=restarting --format '{{.Names}}' | xargs)
[ -z "$unh$rst" ] && push T_NAS_CONTAINERS up "$(docker ps -q | wc -l) running, none unhealthy" || push T_NAS_CONTAINERS down "unhealthy: ${unh:-none}; restarting: ${rst:-none}"

# TrueNAS alerts
al=$(midclt call alert.list | python3 -c '
import json,sys
a=[x for x in json.load(sys.stdin) if not x.get("dismissed")]
bad=[x for x in a if x.get("level") in ("CRITICAL","ERROR","ALERT","EMERGENCY")]
warn=sum(1 for x in a if x.get("level")=="WARNING")
msg="; ".join((x.get("formatted") or x.get("klass",""))[:80].replace(chr(10)," ") for x in bad[:3])
print(("DOWN " if bad else "UP ")+str(len(bad))+" critical/error, "+str(warn)+" warning: "+msg)')
push T_NAS_ALERTS "$( [ "${al%% *}" = UP ] && echo up || echo down)" "${al#* }"

# Cloudflare tunnel
cip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ix-cloudflared-cloudflared-1 2>/dev/null)
rc=$(curl -s -m 5 "http://$cip:20241/ready" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("readyConnections",0))' 2>/dev/null || echo 0)
[ "${rc:-0}" -ge 1 ] && push T_CLOUDFLARED up "readyConnections=$rc" || push T_CLOUDFLARED down "cloudflared not ready (readyConnections=${rc:-0})"

# Public path through Cloudflare (resolve via 1.1.1.1, bypass AdGuard rewrites)
pf=""
chk() { local h=$1 p=$2 want=$3 ip; ip=$(dig +short +time=3 +tries=1 @1.1.1.1 "$h" A | grep -E '^[0-9.]+$' | head -1)
  [ -z "$ip" ] && { pf="$pf $h:nodns"; return; }
  curl -s -m 15 --resolve "$h:443:$ip" "https://$h$p" | grep -q "$want" || pf="$pf $h:fail"; }
# PUBLIC_CHECKS="host|path|needle ..." e.g. "<auth-host>|/api/health|\"OK\" <ntfy-host>|/v1/health|healthy"
for c in ${PUBLIC_CHECKS:-}; do IFS='|' read -r h p w <<<"$c"; chk "$h" "$p" "$w"; done
[ -z "$pf" ] && push T_PUBLIC up "public checks OK via Cloudflare" || push T_PUBLIC down "public path failing:$pf"

# DB dump freshness (db-backup app)
D=${DUMP_DIR:-/mnt/<apps-pool>/Applications/db-dumps}
dump_chk() { # token dir minbytes
  local f; f=$(ls -t "$D/$2"/*.sql.zst 2>/dev/null | head -1)
  if [ -z "$f" ]; then push "$1" down "no dump in $2"; return; fi
  local a sz; a=$(age_h "$f"); sz=$(stat -c %s "$f")
  if [ "$a" -lt 26 ] && [ "$sz" -ge "$3" ] && [ -s "$f.sha1" ]; then push "$1" up "$(basename "$f") ${a}h old, $((sz/1048576)) MiB"; else push "$1" down "$2 dump stale/small: ${a}h, ${sz} B, sha1=$( [ -s "$f.sha1" ] && echo ok || echo missing)"; fi; }
dump_chk T_BK_IMMICH immich 50000000
dump_chk T_BK_FRESHRSS freshrss 1000000
# (authelia/mealie/n8n are not in db-backup config; not monitored - see docs gaps)

# Home Assistant automatic backup on NAS share
f=$(ls -t ${HA_BACKUP_DIR:-/mnt/<apps-pool>/backups/hass}/automatic_backup_*.tar 2>/dev/null | head -1)
if [ -n "$f" ] && [ "$(age_h "$f")" -lt 26 ]; then push T_BK_HA up "$(basename "$f") $(age_h "$f")h old"; else push T_BK_HA down "newest HA backup: ${f:+$(basename "$f") $(age_h "$f")h old}${f:-none}"; fi

# FreshRSS feed actualization: newest entry insertion time (id = microseconds)
na=$(docker exec ix-freshrss-postgres-1 sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select coalesce(max(id),0)/1000000 from freshrss_${FRESHRSS_USER:-<user>}_entry"' 2>/dev/null | tr -d ' ')
if [ -n "$na" ] && [ "$na" -gt 0 ]; then ah=$(( (now - na) / 60 )); [ "$ah" -lt 360 ] && push T_FRESHRSS_FEEDS up "newest article fetched ${ah} min ago" || push T_FRESHRSS_FEEDS down "no new articles for ${ah} min"; else push T_FRESHRSS_FEEDS down "could not query FreshRSS DB"; fi
