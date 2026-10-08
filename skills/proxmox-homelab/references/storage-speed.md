# Backup storage speed diagnosis

Use this when backups run "fast one night, crawling the next". The rule is to measure without changing anything. Real hosts, pools, and disk models are in private context.

## Guardrails
- Don't install packages on the hosts. Use what's already there: `fio`, `smartctl`, `python3`, `proxmox-backup-client`, and on TrueNAS `iperf3`/`fio`.
- Write tests only on pools with plenty of free space. Never on a pool that is ~80%+ full. Cap each test at ~2 GiB, delete the files right away, and check that they're gone.
- Run tests while the system is quiet. Check `cat /proc/pressure/io` and `zpool iostat -y <pool> 3 1`, and stay clear of replication windows (`pvesr status` shows NextSync).
- Never write to an "unused" disk. Raw device tests must use `fio --readonly`. First confirm the disk is not in a pool, an LVM PV, or a mount.
- Redact disk serials from anything you save or report.

## 1. What disks are involved?
```bash
zpool status <pool>; zpool list -v <pool>          # per-vdev fill (a near-full vdev is slower)
smartctl -i -A /dev/disk/by-id/<disk>              # model, hours, 5/187/195/197/199
```
Red flags:
- **DM-SMR HDDs** (e.g. WD Red EFAX, WD40EZAZ/WD Blue EZAZ, many Seagate Barracuda): sustained writes collapse once the CMR cache fills.
- **QLC SSDs** (e.g. Crucial P3 / P3 Plus, Samsung QVO, Intel 660p): writes slow down after the SLC cache fills, and reads of data that has sat a long time get slow.
- Very old drives in a mirror: a mirror writes only as fast as its slowest member.
- `Uncorrectable_Error_Cnt` (187) or reallocated (5) counts growing on a single-disk pool.

## 2. Chunk-store-like write/read test (PBS writes ~4 MiB chunk files)
Copy `scripts/fio-chunk-test.sh` to the host and run `bash fio-chunk-test.sh <pool> <mountpoint>`. It creates a hidden temp directory, writes 512 × 4 MiB with direct I/O and `end_fsync`, reads it back, records `zpool iostat -v` every second, deletes the directory, and prints avg/min/max per 0.5 s plus per-vdev MB/s. A large min/max spread with a low average means the disks set the limit.

## 3. Raw read-only check of an unused disk
```bash
fio --readonly --name=r --filename=/dev/<dev> --rw=read --bs=1M --size=2G --offset=10G \
    --direct=1 --ioengine=libaio --iodepth=8 --output-format=json
```
A QLC drive holding old data can read at tens of MiB/s, which disqualifies it as a "consistent" target.

## 4. Network path without iperf3 on the PVE side
On the receiver (e.g. the NAS) run a short Python socket listener with a timeout. On the PVE node, send 1.5 GiB of zeros with Python sockets. 1GbE saturates at ~111–112 MiB/s (934 Mbit/s). If the disks measure lower than that, the network is not the cause.

## 5. PBS client CPU
`proxmox-backup-client benchmark` with no repository is a local CPU test (SHA256/compress/AES). Skip the repository/TLS variant unless a credential is already provided for it; never dig PBS passwords or tokens out of storage configs.

## 6. Historical throughput
```bash
grep -h vzdump /var/log/pve/tasks/index | tail -50       # find UPIDs
# task logs: "INFO: <pct>% (...) in Ns, read: X MiB/s, write: Y MiB/s" and the final "transferred ... reused" line
```
A run that is mostly "reused" is fast. One that writes many new chunks runs at the speed of the datastore's disks. Compare the lowest per-step write speed, not the overall average.

## Interpreting
- Pick a backup target on its own healthy TLC/MLC SSD, or a CMR HDD mirror of similar-age drives. Avoid SMR vdevs, near-full vdevs, QLC, and a PBS running in a VM on a zvol whose pool also carries media and scrubs.
- A secondary PBS that only pulls can stay on slow disks, because its speed doesn't affect the source.
