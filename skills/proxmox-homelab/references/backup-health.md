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

## 6. Data-level backups (more important than VM images for Luke)
Luke backs up data inside guests rather than whole VMs, so always audit these too. They are read-only checks; hosts, IDs, and paths are in private context.

**Home Assistant** (inside the HAOS VM, through the guest agent; output is JSON, so parse it and never print `password`):
```bash
qm guest exec <haos-vmid> --timeout 60 -- docker exec hassio_cli ha backups list --raw-json   # dates, size, locations, addons
qm guest exec <haos-vmid> --timeout 60 -- docker exec hassio_cli ha mounts info --raw-json    # NAS backup mount state
qm guest exec <haos-vmid> --timeout 60 -- docker exec homeassistant python3 -c '<read /config/.storage/backup: config.create_backup agent_ids/include_addons/include_all_addons, schedule, retention, last_completed; backups[].failed_agent_ids>'
```
- Add-ons not listed in `include_addons` (with `include_all_addons: false`) are **not** in the daily backup. Their only copies are the pre-update partials HA makes on updates, and those stay on the local disk.
- Add-on data lives under `/mnt/data/supervisor/app_configs/<slug>` on newer HAOS (it used to be `addons/data`). `du -sh` it to size the gap.
- `/mnt/data` usage: pre-update partials pile up and fill the data partition.

**TrueNAS side** (as root on the NAS):
```bash
midclt call pool.snapshottask.query          # dataset, recursive, schedule, lifetime
midclt call replication.query; midclt call cloudsync.query; midclt call rsynctask.query
zfs list -H -t snapshot -o name,creation -s creation -d 1 <dataset> | tail -1   # newest per dataset
zfs list -d 2 -o name,used,usedbysnapshots,refer <pool>                        # snapshot cost
```
**Backrest** (restic): query the API inside the container on its loopback port with `POST /v1.Backrest/GetOperations` and a body of `{"selector":{"planId":"<id>"},"lastN":N}`. A `repoId` selector is ignored. Read the plan list from its `config.json` and check each plan's `schedule.disabled`. **Plans that exist but have schedules disabled look healthy in the UI and quietly stop.** Signature for a partial run: `BACKUP_PARTIAL` / `open … permission denied` on root-owned 0600 files.

**tiredofit/db-backup**: `docker logs --since 24h db-backup`. The signature `Postgres Host '<host>' is not accessible, retrying.. (N seconds so far)` means the source app is stopped and the container keeps retrying forever, blocking the later dumps in that run. Compare the newest file in each dump folder with the schedule.

**Report per item:** what is protected, where to, last success, retention, and the gap (no offsite copy, schedule off, excluded add-on, same-pool-only snapshots).

## 7. Reporting
Report: jobs present (yes/no), unprotected guests, newest backup per guest per store, failing signatures with exact non-secret error lines, verify/prune/sync job presence, and proposed fixes as approval items.
