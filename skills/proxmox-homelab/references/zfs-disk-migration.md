# Move a ZFS-backed VM to a new disk and keep pvesr replication

Use this when the single disk behind a Proxmox `zfspool` storage is failing and its guests must move to a new disk. The storage ID, the guest configs, and incremental replication all stay the same, and downtime is one guest shutdown and boot (about 2–3 minutes for HAOS). Real pool names, VMIDs and disks are in private context. **Changing pools needs Luke's explicit approval.**

## Why rename pools instead of `qm disk move`
- pvesr requires the **same storage ID on source and target**, and a `zfspool` storage ID maps to a single pool name cluster-wide. Moving the disk to a new storage ID breaks replication.
- `zpool attach`/`replace` needs a new disk at least as large as the old one. A smaller replacement can't join the pool.
- `zfs send -R` keeps the `__replicate_<job>_<ts>__` snapshot with the same GUID, so the next replication run stays incremental.

## Pre-flight (read-only)
1. New disk, identified by `/dev/disk/by-id`. Check that `lsblk` shows no partitions, `wipefs -n` and `blkid -p` find nothing, it has no holders, and it is not in `pvs`, `/proc/mounts`, `zpool status` or swap.
2. Record `qm config <vmid>`, `pvesr status`, `ha-manager status`, and `zfs list -t all -r <pool>` on both nodes.
3. List **everything** in the old pool (`zfs list -t all -r <pool>`). Every dataset, including stopped guests' disks, must move, or the pool can't be renamed.
4. Note the pool properties to copy: `zpool get ashift,autotrim,cachefile`, plus `zfs get -s local all <pool>`. On PVE, pools are usually imported by `zfs-import@<pool>.service` with `cachefile=none`.
5. Delete dead replication jobs to an offline node first: `pvesr delete <job> --force`. Force removes only the config, so then destroy that job's `__replicate_<job>_*` snapshots on source and target by exact name. A stale one can pin tens of GB.
6. Take an app-level backup and get it off the old disk (see HA notes below).

## Procedure
```bash
# temp pool on the new disk
zpool create -o ashift=12 -o autotrim=on -o cachefile=none -O compression=on <pool>new /dev/disk/by-id/<new-disk>
pvesr disable <vmid>-<job>                      # freeze replicate snapshots for the window
zfs snapshot -r <pool>@mig1
zfs send -R -c <pool>@mig1 | zfs recv -Fu <pool>new   # guest keeps running; ~300 MB/s SATA SSD to SSD
# verify per-dataset snapshot GUIDs match (zfs get -H -o value guid ...)
```
Cutover. Script it with a rollback function and a GUID check before every import, and run it with `nohup` on the node:
```bash
OLD=$(zpool get -H -o value guid <pool>); NEW=$(zpool get -H -o value guid <pool>new)
qm shutdown <vmid> --timeout 240              # graceful; abort (no changes) if it doesn't stop; never force
zfs snapshot -r <pool>@mig2
zfs send -R -c -I @mig1 <pool>@mig2 | zfs recv -Fu <pool>new   # seconds
# verify GUIDs of @mig2 and that the __replicate_ snapshot exists on <pool>new
zpool export <pool>      && zpool import -o cachefile=none $OLD <pool>-old    # rollback copy, untouched
zpool export <pool>new   && zpool import -o cachefile=none $NEW <pool>
pvesm list <storage-id> | grep vm-<vmid>-disk  # storage.cfg needs no edits
qm start <vmid>
```
Rollback before the guest is back: export the new pool (and `<pool>-old`), run `zpool import $OLD <pool>`, then start the guest.

## After
- Destroy `@mig1/@mig2` on the **new** pool only, before re-enabling replication; otherwise `-I` sends them to the target. Keep them on `<pool>-old`.
- `pvesr enable <job>; pvesr schedule-now <job>`, then check `/var/log/pve/replicate/<job>` for `incremental sync … => …` and `OK`.
- Verify the guest: web UI, both NICs/VLANs (guest agent `network-get-interfaces`), and app services.
- `<pool>-old` was imported with `cachefile=none`, so it won't auto-import on reboot; it stays on disk as the rollback. Destroying or wiping it is a separate decision for Luke.
- Measure downtime with a 2-second HTTP probe loop on the node.

## HA (Proxmox HA manager) caution
If `ha-manager status` shows a stale `service vm:<id>` that is not in `resources.cfg` while the stack is **disarmed**, `ha-manager remove` refuses ("not HA managed"). The only supported cleanup is `ha-manager crm-command arm-ha`. That re-opens the CRM master's watchdog for up to ~90 rounds before it goes idle, so with a zero-margin quorum it adds fencing risk. Leave it to Luke; a disarmed stack ignores the entry.
