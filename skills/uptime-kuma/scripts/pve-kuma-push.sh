#!/bin/bash
# Labby: read-only Proxmox health checks pushed to Uptime Kuma (Kuma CT). Runs every 5 min from /etc/cron.d/labby-kuma-push.
# Never changes cluster/guest state. Tokens: /root/labby-kuma/tokens.env (600). Docs: private notes
set -u
. /root/labby-kuma/tokens.env
KUMA=${KUMA:-http://<kuma-ip>:3001}
PVEL=${PVEL_IP:?set PVEL_IP}
now=$(date +%s)
push() { local tok=${!1:-}; [ -z "$tok" ] && return
  curl -fsS -m 10 -G "$KUMA/api/push/$tok" --data-urlencode "status=$2" --data-urlencode "msg=${3:0:250}" -o /dev/null || echo "push $1 failed" >&2; }

# Quorum
q=$(pvecm status 2>&1); tv=$(awk -F: '/Total votes/{gsub(/ /,"",$2);print $2}' <<<"$q"); ev=$(awk -F: '/Expected votes/{gsub(/ /,"",$2);print $2}' <<<"$q")
grep -q 'Quorate: *Yes' <<<"$q" && push T_PVE_QUORUM up "quorate, votes $tv/$ev (zero margin while pve2 is offline)" || push T_PVE_QUORUM down "NOT quorate: votes ${tv:-?}/${ev:-?}"

# ZFS on pve and pvel
zmsg=""; zok=1
for h in local pvel; do
  if [ $h = local ]; then out=$(zpool status -x 2>&1; zpool list -H -o name,cap 2>&1); else out=$(ssh -n -o BatchMode=yes -o ConnectTimeout=8 root@$PVEL 'zpool status -x; zpool list -H -o name,cap' 2>&1) || { zok=0; zmsg="$zmsg pvel:unreachable"; continue; }; fi
  head -1 <<<"$out" | grep -q 'all pools are healthy' || { zok=0; zmsg="$zmsg $h:$(head -1 <<<"$out")"; }
  full=$(tail -n +2 <<<"$out" | tr -d % | awk '$2>=85{print $1"="$2"%"}' | xargs); [ -n "$full" ] && { zok=0; zmsg="$zmsg $h full:$full"; }
done
[ $zok = 1 ] && push T_PVE_ZFS up "pools healthy on pve + pvel" || push T_PVE_ZFS down "${zmsg# }"

# Guests with onboot=1 must be running
res=$(pvesh get /cluster/resources --type vm --output-format json)
bad=$(for f in /etc/pve/nodes/*/qemu-server/*.conf /etc/pve/nodes/*/lxc/*.conf; do grep -q '^onboot: 1' "$f" && basename "$f" .conf; done | RES="$res" python3 -c '
import json,os,sys
r={str(g["vmid"]):g for g in json.loads(os.environ["RES"])}
print(" ".join(v+"("+r.get(v,{}).get("name","?")+")="+r.get(v,{}).get("status","missing") for v in sys.stdin.read().split() if r.get(v,{}).get("status")!="running"))' 2>&1) || bad="check-failed"
[ -z "$bad" ] && push T_PVE_GUESTS up "all onboot guests running" || push T_PVE_GUESTS down "not running: $bad"

# Replication jobs (all enabled jobs): no failures, last sync < 1 h
rep=$(pvesh get /nodes/$(hostname)/replication --output-format json | python3 -c '
import json,sys,time
bad=[j["id"]+":fail="+str(j.get("fail_count",0)) if j.get("fail_count") else j["id"]+":last "+str(int((time.time()-j.get("last_sync",0))/60))+"m"
     for j in json.load(sys.stdin) if not j.get("disable") and (j.get("fail_count") or time.time()-j.get("last_sync",0)>3600)]
print(" ".join(bad))' 2>&1) || rep="check-failed"
[ -z "$rep" ] && push T_PVE_REPL up "replication jobs OK, synced < 1 h" || push T_PVE_REPL down "replication: $rep"

# vzdump freshness: VZDUMP_MAX_AGE_H JSON {vmid: max_age_hours}
vz=$(pvesh get /nodes/$(hostname)/storage/${PBS_STORAGE:-pbs-nas}/content --content backup --output-format json | python3 -c '
import json,sys,time
b={}
for x in json.load(sys.stdin): b[str(x["vmid"])]=max(b.get(x["vmid"],0),x.get("ctime",0))
want=json.loads(__import__("os").environ.get("VZDUMP_MAX_AGE_H","{}"))  # export in tokens.env, e.g. {"<kuma-ct>":30,"<weekly-vm>":192}
print(" ".join(f"{v}:{int((time.time()-b.get(v,0))/3600)}h" for v,h in want.items() if time.time()-b.get(v,0)>h*3600))' 2>&1) || vz="check-failed"
[ -z "$vz" ] && push T_PVE_VZDUMP up "watched guest backups fresh on ${PBS_STORAGE:-pbs-nas}" || push T_PVE_VZDUMP down "stale backups: $vz"

# OTBR inside a VM on an isolated VLAN (not reachable from Kuma): OTBR_VMID
st=$(timeout 25 qm guest exec ${OTBR_VMID:?} --timeout 15 -- curl -s -m5 http://127.0.0.1:8081/node/state 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("out-data","").strip().strip("\""))' 2>/dev/null)
case "$st" in leader|router|child) push T_OTBR up "Thread state: $st";; *) push T_OTBR down "OTBR state: ${st:-no answer (guest agent/otbr-agent)}";; esac

# PBS storages
pb=$(pvesm status 2>/dev/null | awk '$2=="pbs"{gsub(/%/,"",$7); if($3!="active"||$7+0>=90) printf "%s:%s/%s%% ",$1,$3,$7; else ok=ok $1"="$7"% "} END{print "|" ok}')
[ "${pb%%|*}" = "" ] && push T_PBS up "${pb#*|}" || push T_PBS down "${pb%%|*}"
