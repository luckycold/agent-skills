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
| `prune '<vm>': … missing Datastore.Modify\|Datastore.Prune on /datastore/<store>` after "transferred … reused …" | Backup succeeded, but the PVE storage's PBS token cannot prune. Snapshots accumulate and an email goes out every night. | On that PBS, back up `/etc/proxmox-backup/acl.cfg`, then `proxmox-backup-manager acl update /datastore/<store>[/<ns>] DatastorePowerUser --auth-id '<user>!<token>'` (PBS 4.x: Backup + Prune). `Datastore.Prune` only works on groups the token **owns** (`<store>/<type>/<id>/owner`), so synced or other-owner groups stay untouchable; `DatastoreAdmin`/`Datastore.Modify` would reach everything. Verify with `vzdump <id> --prune-backups keep-last=N` → `pruned 0 backup(s)` and no error. Caveat: after the grant, any manual vzdump to that storage without its own retention applies the **storage-default** `prune-backups`, so check owned groups that hold deliberate keep-all history. Or drop the PVE-side `prune-backups` and let a PBS prune job own retention. |
| `ssh … exit code 255` in `pvesr status` | Replication target node unreachable | See SKILL.md "Replication and offline nodes" |
| `unable to freeze guest fs … Another job is running for job group <addon>` | HAOS fsfreeze hook busy (add-on job running) | Usually transient; check whether it repeats |

### Disabled pruning with an inherited backup cap

A job with remove=0 can still inherit a finite prune-backups policy from its
storage or vzdump defaults. Once the guest reaches that count, the next backup
fails before transferring data with "There is a max backup limit". Disabling
removal alone does not remove the inherited limit.

When keeping every snapshot is authorized and intended, use the native per-job
prune-backups=keep-all=1 setting. In the verified PVE implementation, keep-all
disables the client backup-count limit and prevents the removal code path. It
does not change PBS-side prune jobs or grant additional token permissions.
Prefer the owned job's setting over modifying shared storage retention.

```bash
pvesh set /cluster/backup/<job-id> --prune-backups keep-all=1
vzdump <vmid> --storage <pbs-storage-id> --remove 0 --prune-backups keep-all=1
```

Preserve the prior job configuration before editing. Verify the API's parsed
keep-all field, backup task success and retained snapshots. Keep-all needs
capacity planning; do not select it merely to bypass a retention decision.

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
- One-off full backup to a mount: `ha backups new --name ... --location=<mount>` (the `=` is required, because `--location NAME` fails with `unknown command`). To keep it encrypted with HA's configured key, read the key inside HAOS and pass it without printing. Add-ons with locally built images export that image to `/mnt/data/supervisor/tmp` first, so check `/mnt/data` has free space of at least the image size. Run it detached (`qm guest exec … -- sh -c "nohup sh /mnt/data/x.sh &"`; piping a script on stdin into a background `sh` loses it) and poll `ha jobs info`.

**TrueNAS side** (as root on the NAS):
```bash
midclt call pool.snapshottask.query          # dataset, recursive, schedule, lifetime
midclt call replication.query; midclt call cloudsync.query; midclt call rsynctask.query
zfs list -H -t snapshot -o name,creation -s creation -d 1 <dataset> | tail -1   # newest per dataset
zfs list -d 2 -o name,used,usedbysnapshots,refer <pool>                        # snapshot cost
```
**TrueNAS cloud sync (rclone):** `cloudsync.query` returns provider credentials, so filter it with `jq` (e.g. `{id,description,path,transfer_mode,exclude,job:{state,error}}`). Excludes are rclone `- <pattern>` filter lines relative to the task's `path` (anchor with a leading `/`). The `Immich Backup` task (pCloud, SYNC, `/mnt/Apps/Applications/immich`) excludes `/data/encoded-video/**` and `/data/thumbs/**` (since Oct 2026): they are regenerable and in-progress transcodes fail the whole run with `can't copy - source file is being updated` (exit 6), which keeps Kuma's TrueNAS-alerts monitor red. SYNC without `--delete-excluded` leaves already-uploaded excluded files on the remote. `cloudsync.sync <id> '{"dry_run": true}'` works; read `/var/log/jobs/<job>.log` for `Skipped delete` lines (routine ones: rotated `data/backups` dumps and old `pg_wal` segments). A successful run clears the `CloudSyncTaskFailed` alert by itself.

**Backrest** (restic): query the API inside the container on its loopback port with `POST /v1.Backrest/GetOperations` and a body of `{"selector":{"planId":"<id>"},"lastN":N}`. A `repoId` selector is ignored. Read the plan list from its `config.json` and check each plan's `schedule.disabled`. **Plans that exist but have schedules disabled look healthy in the UI and quietly stop.** Signature for a partial run: `BACKUP_PARTIAL` / `open … permission denied` on root-owned 0600 files.

**tiredofit/db-backup**: `docker logs --since 24h db-backup`. The signature `Postgres Host '<host>' is not accessible, retrying.. (N seconds so far)` means the source app is stopped and the container keeps retrying forever, blocking the later dumps in that run. Compare the newest file in each dump folder with the schedule. Leftover dump folders whose DB is no longer in the `DBxx_*` env list are a silent gap.

**Consistent DB coverage:** a raw copy of a live Postgres/MySQL data dir is not a backup (a same-pool ZFS snapshot is only crash-consistent and local). For app DBs outside db-backup, `truenas-custom-apps/scripts/pg-dump-exec.sh` runs `pg_dump` via `docker exec` on the container's local socket (no passwords, no extra Docker networks), writes db-backup's layout (`.sql.zst` + `.sha1` + `latest-*`, uid 568, 0600), checks `zstd -t` and the `dump complete` footer, adds a `pg_dumpall --roles-only --no-role-passwords` file (pg_dump has no CREATE ROLE; apps such as Warracker own objects with an extra role, so a restore without it fails), and can tar root-only file dirs the reader cannot open. Schedule it from TrueNAS cron after db-backup and before the Backrest runs, make sure each folder is in a **scheduled** off-site plan, and add a freshness push to Kuma that globs `pgsql_*` (a bare `*.sql.zst` picks the tiny roles file). **Cleanup must only delete what the script wrote:** it keeps a per-folder manifest and never globs; a glob cleanup once deleted another tool's older dumps. SQLite apps: `sqlite3 <db> ".backup <out>"` (consistent), not `cp`. Restore test: a throwaway container of the same image/major (pgvector etc.) with `--network none` and `POSTGRES_HOST_AUTH_METHOD=trust`, `POSTGRES_USER` = the dump's owner; load the roles file, then pipe the dump through `psql -v ON_ERROR_STOP=1`, count tables and live rows. `zstd -dc` skips symlinks, so resolve `latest-*` with `readlink -f`.

**SQLite apps:** `truenas-custom-apps/scripts/sqlite-dump.py` (TrueNAS cron, as root). Open each live DB as `file:<path>?mode=ro` (a read-only connection never creates `-wal`/`-shm`, so no root-owned files appear next to the app's DB; diff a before/after listing of the DB dirs to prove it) and copy with the online-backup API in one step, set the copy to `journal_mode=DELETE`, `PRAGMA integrity_check`, then `zstd --rsyncable` (keeps restic dedup across days) + sha1 + manifest cleanup. Quirks: Plex needs a stub `icu_root` collation and gets `quick_check` (its FTS `spellfix1` tables can't be counted); Audiobookshelf has a trigger (`UPDATE … ORDER BY`) the host SQLite can't parse, so set `writable_schema=ON` on the copy before checking. Raw DB sizes can be 4x the ZFS `du` (hexos `local.db` 2.1 GB). Ship the DB copies plus a tiny tar of the app's key/config files (`config.xml`, `Preferences.xml`, lldap's data dir) rather than whole config dirs (metadata/caches are rebuildable). Backrest runs as uid 568, so root-only sources (HA backup share) need a copy into the dump dir (`cp --reflink=auto`, keep HA's mtime).

**SQLite on another host (e.g. a monitoring LXC):** pull, don't push. Give the dump host a dedicated key whose `authorized_keys` line is `from="<dump host>",command="<stream script>",restrict`; the script does `sqlite3 -readonly <db> ".backup <tmpfs>"`, `quick_check`, `cat`, removes the temp dir. Pin the host key in a separate `UserKnownHostsFile`, ignore the agent (`IdentitiesOnly`, no `SSH_AUTH_SOCK`), then run the stream through the same local pipeline (`remote=` job in `truenas-custom-apps/scripts/sqlite-dump.py`). Prove the restriction (other commands ignored, forwarding "prohibited") and restore-test from the off-site repo too (`restic dump latest <file>` inside the Backrest container, password fed on stdin).

**Restic recovery secrets:** repo passwords live only in Backrest's `config.json`; keep a Pass custom item (hidden field per repo + URIs + gzip/base64 of the config) and re-create it whenever repos change (`pass-cli item create custom --from-template -` via stdin; verify by comparing hashes, not values; `item view --field` can't read section fields, use `--output json`).

**Backrest API (auth off) gotchas:** (new plans: if `Backup` says "plan not found", send the unchanged config with SetConfig once more and wait a few seconds) `AddRepo` wants `{"repo": {...}}` (a bare repo body nil-panics the handler, no restart) and initialises the restic repo. Copy `prunePolicy`/`checkPolicy` from a sibling repo. After `AddRepo` + `SetConfig`, the scheduler can miss new plans ("plan not found" on `Backup`); check the log for `backup for plan "<id>"` and re-`SetConfig` the unchanged `GetConfig` to re-apply. `GetConfig` redacts `sync.identity` keys (SetConfig keeps them), so the real rollback copy is Backrest's own `config.json.bak.<ts>`. A long-stale restic lock fails `forget` ("repository is already locked"): `DoRepoTask {"repoId":..,"task":"TASK_UNLOCK"}`. New repo passwords are only in Backrest's config, so the config needs its own off-box copy.

**Report per item:** what is protected, where to, last success, retention, and the gap (no offsite copy, schedule off, excluded add-on, same-pool-only snapshots).

## 7. Reporting
Report: jobs present (yes/no), unprotected guests, newest backup per guest per store, failing signatures with exact non-secret error lines, verify/prune/sync job presence, and proposed fixes as approval items.
