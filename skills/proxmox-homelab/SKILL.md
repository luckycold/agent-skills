---
name: proxmox-homelab
description: Access, inventory, and health-check Luke's Proxmox VE home lab (cluster nodes, guests, ZFS/PBS storage, backups, replication, notifications) from a remote agent over WireGuard with the Proton Pass SSH agent. Use for any Proxmox, PBS, vzdump, guest, or "learn/check the home lab" task.
author: Luke
category: devops
---

# Proxmox Home Lab

Proxmox is the primary entry point into Luke's home. Any agent (Labby, Codex, Cursor, Claude, OpenCode, Hermes) can follow this skill. Resolve every real host, address, VMID, storage ID, and node name from the ignored `~/.agents/private-context.md` (section **Proxmox home lab**). This public skill uses placeholders only.

Load with: `infrastructure-hygiene` (general rules, Hermes boundary), `proton-pass-cli` (SSH agent), `truenas-custom-apps` (NAS side), and `ntfy-ops` (notifications).

## Rules

- Stay read-only unless Luke explicitly asks for a change. Never start, stop, migrate, or reconfigure guests, jobs, HA, or storage as a side effect of inspection.
- Before any approved change, save a dated copy of the config being changed under `/root/` on the node. Guests: `/etc/pve/nodes/<node>/qemu-server/<vmid>.conf`. Backup jobs: `/etc/pve/jobs.cfg`.
- Never paste `/etc/pve/storage.cfg`, `/etc/pve/priv/*`, notification configs, or PBS token files into chat, logs, or Git. Storage plugins (for example the TrueNAS NVMe/TCP plugin) keep API keys there in plaintext. Redact before saving raw output.
- Do not create new SSH keys. Use the Proton Pass **Main** vault key through the Pass SSH agent.

## Access recipe

1. **Tunnel.** From an off-LAN box, bring up the home WireGuard interface (`<home-wg-iface>`). Check `ip -br a` and `sudo wg show`. If it's down, run `sudo wg-quick up <home-wg-iface>`. The peer's AllowedIPs cover only the home LAN; check the latest handshake.
2. **Pass session.** Load the box's Pass CLI env file, if one exists (path in private context), then run `pass-cli info`. If it's unauthenticated, stop and ask Luke. Never start an interactive login from automation.
3. **SSH agent.** Reuse a running agent if there is one (`pgrep -af 'pass-cli ssh-agent'`, socket path in private context). Otherwise run:
   `pass-cli ssh-agent start --socket-path <sock> --vault-name Main --refresh-interval 30` (or `ssh-agent daemon start …`).
   Verify with `SSH_AUTH_SOCK=<sock> ssh-add -l`.
4. **Connect by IP**: `SSH_AUTH_SOCK=<sock> ssh -o BatchMode=yes root@${PVE_IP}`. Do **not** trust the node's friendly DNS name. Through home DNS, it may resolve to the reverse-proxy/Traefik address instead of the hypervisor.
5. **Other nodes** are reachable from the primary node over cluster SSH trust (`ssh root@${PVEL_IP}` from the node). The same Pass key also reaches the NAS root shell.
6. **Batch scripts.** If you pipe a script into `ssh … 'bash -s' <<'EOF'`, every **nested** `ssh` inside the script must use `-n` (or `</dev/null`). Otherwise it consumes the rest of the heredoc and the script silently stops. The same applies to `pct exec` and `qm guest exec`.
7. There is no Proxmox API token for agents yet. Use SSH + `pvesh`. If Luke wants API access, propose a least-privilege `PVEAuditor` token and store it in Pass.

## Inventory refresh

Run `scripts/pve-inventory.sh` (read-only; see the header for usage) or the checklist in [references/inventory-commands.md](references/inventory-commands.md). Save output under a private working directory and redact `tn_api_key` and similar values. Summarize into a dated inventory and update **private context** (not this skill) with verified facts. Facts to capture:

- PVE version, running kernel, pending updates, enabled repos (enterprise + no-subscription both enabled means apt errors).
- Cluster: `pvecm status` expected vs total votes. A cluster with one node offline can be quorate with **zero margin**; flag it.
- Guests: `qm list`, `pct list`, `/cluster/resources`, descriptions/tags, NIC bridges and VLAN tags, guest-agent IPs.
- Storage: `pvesm status`, `zpool status -x`, last scrub, thin-pool usage, disks with no partitions or signatures (possibly unused).
- Extra host services (reverse proxy, remote-agent servers, tunnels).

## Backup health (check every time)

See [references/backup-health.md](references/backup-health.md) for commands and failure signatures. Minimum checks:

1. `cat /etc/pve/jobs.cfg` and `pvesh get /cluster/backup`. **Empty means no scheduled guest backups at all.**
2. `pvesh get /cluster/backup-info/not-backed-up`. Every guest listed is unprotected.
3. The latest snapshot age per guest on each PBS storage (`pvesh get /nodes/<node>/storage/<pbs-id>/content`). Old groups can make a datastore look healthy while nothing current is protected.
4. vzdump task history and `/var/log/vzdump/qemu-<vmid>.log`. A job that transfers data successfully and then fails with `permission check failed - missing Datastore.Modify|Datastore.Prune` is a **PBS ACL problem on the backup token**, not a data problem. Snapshots pile up unpruned.
5. Disks with `backup=0` (Luke's HAOS VM main disk) are skipped by vzdump. That guest relies on ZFS replication and the app's own backups; say so explicitly.
6. A secondary PBS that **pulls** from the primary only mirrors what the primary holds. A stale primary means a stale off-box copy.
7. Data-level backups (Home Assistant's own backups, TrueNAS snapshot tasks, Backrest/restic, db-backup dumps) matter more than VM images for Luke. Audit them with section 6 of the runbook. A Backrest plan whose schedule is disabled looks healthy but has stopped running.

## Backup speed and target choice

When backups run at inconsistent speeds, or you need to pick a PBS target disk, follow [references/storage-speed.md](references/storage-speed.md): identify SMR, QLC, and aging disks; run the capped `scripts/fio-chunk-test.sh` (2 GiB, self-deleting, only on pools with plenty of free space); run read-only raw tests on unused disks; and run a socket throughput test for the network. PBS writes only new chunks, so speed swings track the datastore disks, not the source.

## Drive and port audit

For a read-only drive health/speed/port audit across hosts, run `scripts/drive-inventory.sh` and follow [references/drive-audit.md](references/drive-audit.md) (classification rules, slot-occupancy and port-sharing gotchas, report format).

## Replication and offline nodes

- `pvesr status`: a job targeting an offline node fails with SSH exit 255 and keeps retrying. Confirm whether the node is intentionally retired (look for dated notes under `/root/`) before proposing removal of the job or the node.
- `ha-manager status`: stale services pinned to an offline node, or `hastate: request_stop` on a running guest, mean leftover HA state. Report it. Clean it up only with an explicit plan, because HA can stop guests.
- To move guests off a failing single-disk ZFS pool while keeping the storage ID and incremental replication, follow [references/zfs-disk-migration.md](references/zfs-disk-migration.md) (send -R to a temporary pool, then a short-shutdown cutover with pool renames and a GUID-checked rollback).
- To move a VM with USB passthrough (radio sticks) to another node, or to cap ZFS ARC before adding guests, follow [references/usb-passthrough-migration.md](references/usb-passthrough-migration.md).
- Removing a dead node (`pvecm delnode`) and fixing expected votes are cluster changes that need Luke's approval and a quorum plan (see `infrastructure-hygiene/references/proxmox-cluster-ceph.md`).

## Notifications

- `/etc/pve/notifications.cfg` lists targets and matchers. Read only target names, types, and modes; never print credentials.
- If postfix logs `status=deferred (alias database unavailable)` for root mail, the local `mail-to-root` target is silently queueing. The fix (on approval) is `newaliases` and then flushing the queue.
- Luke runs ntfy. To add a PVE webhook/Gotify-style ntfy target, follow `ntfy-ops`.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update this package when a verified reusable correction or repeatable workflow would improve future runs. Keep live topology in `~/.agents/private-context.md` (and its Proton Pass note), never here. Follow `personal-skill-maintenance` for review, the public-safety check, and publishing.
