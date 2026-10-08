# Proxmox backup health runbook

Read-only diagnosis first. Changing jobs, ACLs, or retention requires Luke's approval.

## 1. Are any jobs scheduled?
```bash
cat /etc/pve/jobs.cfg                       # empty file = no vzdump jobs
pvesh get /cluster/backup --output-format json-pretty
pvesh get /cluster/backup-info/not-backed-up --output-format json
```
`ls -la /etc/pve/jobs.cfg` shows when the jobs were last edited. Correlate that with any job deletions Luke asked for.

## 2. How fresh is each guest's newest backup?
```bash
for s in <pbs-storage-ids>; do
  pvesh get /nodes/<node>/storage/$s/content --output-format json | python3 -c '
import json,sys,datetime,collections
g=collections.defaultdict(list)
for x in json.load(sys.stdin): g[x.get("vmid")].append(x.get("ctime",0))
for k,v in sorted(g.items(),key=lambda kv:str(kv[0])):
  print(k,len(v),datetime.datetime.fromtimestamp(max(v)).strftime("%F"))'
done
```
Anything older than the intended schedule is a gap. Groups for VMIDs that no longer exist are historical leftovers. VMIDs get reused, so check the backup notes and names before restoring.

## 3. Why did a job fail?
```bash
grep -h vzdump /var/log/pve/tasks/index | tail -30
tail -30 /var/log/vzdump/qemu-<vmid>.log
journalctl -u pvescheduler --since -7d | grep -E 'ERROR|finished'
```
Known signatures:

| Log line | Meaning | Fix (on approval) |
|---|---|---|
| `prune '<vm>': … missing Datastore.Modify\|Datastore.Prune on /datastore/<store>` after "transferred … reused …" | Backup succeeded, but the PVE storage's PBS token cannot prune. Snapshots accumulate and an email goes out every night. | On that PBS, grant the token `DatastorePowerUser` (or add `Datastore.Prune`) on `/datastore/<store>`. Or drop the PVE-side `prune-backups` and let a PBS prune job own retention. |
| `ssh … exit code 255` in `pvesr status` | Replication target node unreachable | See SKILL.md "Replication and offline nodes" |
| `unable to freeze guest fs … Another job is running for job group <addon>` | HAOS fsfreeze hook busy (add-on job running) | Usually transient; check whether it repeats |

Notifications: one failure can produce two emails when two targets match (SMTP + `mail-to-root`).

## 4. Guests that vzdump cannot protect
- Disks with `backup=0` are skipped. Luke's HAOS VM main disk is one; it relies on ZFS replication to another node plus Home Assistant's own backups. State this whenever you report backup coverage.
- USB-passthrough guests restore fine, but the device stays tied to the host node.

## 5. PBS topology checks
```bash
pct exec <pbs-ctid> -- proxmox-backup-manager prune-job list </dev/null
pct exec <pbs-ctid> -- proxmox-backup-manager verify-job list </dev/null   # none = never verified
pct exec <pbs-ctid> -- proxmox-backup-manager task list --all --limit 60 </dev/null
```
- A secondary PBS (Luke's runs as a VM on the NAS) may **pull** from the primary with a sync token. It mirrors only what the primary holds, so if the primary is stale, the off-box copy is stale too.
- Guests on NAS-backed storage and a PBS on the same NAS share one failure domain. Keep an independent off-site copy.
- Host configuration (`/etc/pve`, `/etc/network/interfaces`) is not inside guest backups. Recommend a separate host-config backup.

## 6. Reporting
Report: jobs present (yes/no), unprotected guests, newest backup per guest per store, failing signatures with exact non-secret error lines, verify/prune/sync job presence, and proposed fixes as approval items.
