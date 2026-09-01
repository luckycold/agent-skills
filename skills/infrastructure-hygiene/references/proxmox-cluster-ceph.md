# Proxmox cluster, storage, replication, and backup recovery

Use this reference for reusable Proxmox recovery patterns. Resolve node names, guest IDs, storage IDs, addresses, device paths, and credentials from the ignored `~/.agents/private-context.md`. Never copy live topology into this public repository.

## Quorum and SSH

- Proxmox root SSH authorization is commonly backed by pmxcfs at `/etc/pve/priv/authorized_keys`. Stopping `pve-cluster` can make key authentication fail even when the key content is correct.
- Restore quorum by recovering or joining a member rather than taking pmxcfs down on a surviving node.
- Confirm link state, DNS, time synchronization, corosync reachability, and current votes before attempting a join.
- `pvecm add <existing-member-ip> --use_ssh 1` uses established SSH. A `--fingerprint` value refers to the API TLS certificate fingerprint, not an SSH host key.

## Major-version upgrades

- Follow the vendor's current upgrade guide and run its preflight checker before changing repositories.
- Userspace can be upgraded while the old kernel remains active; verify `uname -r` after reboot.
- Preserve quorum during rolling reboots. Do not reboot multiple voting members together unless the cluster design explicitly tolerates it.
- Virtual-media installers need an HTTP server that supports Range requests.
- Re-check DKMS, GPU, NIC, HBA, and passthrough compatibility against the target kernel before rebooting.

## Ceph retirement and disk safety

- Never purge Ceph or wipe a device until `lsblk`, `pvs`, `zpool import`, mounts, holders, and `/etc/pve` references prove it is not an OS disk or live storage member.
- A stale partition label is not proof of a usable pool. Require multiple independent checks before reuse.
- Remove storage references and Ceph services in a controlled order, verify no guest still depends on RBD/CephFS, then mask retired services only after the cluster is healthy.
- Do not recreate Ceph merely because historical configuration mentions it. Re-read the current architecture decision.

## Local ZFS replication

- `pvesr` requires the same Proxmox storage ID on source and target; matching pool names alone are not sufficient unless they are registered consistently.
- Create and verify target pools before adding replication jobs.
- Replication follows the node currently hosting the guest. Validate the schedule, `pvescheduler`, guest locks, source snapshots, and received target datasets.
- A pending job with no `zfs send` activity can indicate a scheduler or cluster-filesystem lock problem; inspect logs before restarting the scheduler.
- HA restart from replicated local ZFS is active-passive and has an RPO equal to the last successful replication. It is not live migration and does not move USB passthrough devices.

## HAOS placement decision

Measure rather than assume. On low-bandwidth or high-latency cluster networks, small-block RBD performance may be much worse than local SSD/ZFS. Local ZFS plus scheduled replication and `ha-manager` restart can be the better tradeoff when the accepted RPO is explicit. A mirror protects against disk failure within one node; it does not provide node failover.

## Proxmox Backup Server

- Use PBS backups for ordinary guests and reserve `pvesr` for workloads that specifically need short-RPO restart on another PVE node.
- Keep the primary and secondary backup copies on failure domains that do not disappear together.
- Use PBS remote sync for off-box copies rather than replicating the PBS container itself.
- Grant API tokens only the required datastore audit/read/backup roles and keep token IDs and values in private context.
- Rate-limit remote sync when it shares constrained network links with latency-sensitive workloads.
- Verify restore paths, not only successful backup jobs.

## TrueNAS-hosted PBS pitfalls

- Keep VM disks on deliberate datasets/zvols rather than application-runtime storage.
- Let child datasets inherit a correct parent mountpoint; avoid accidentally creating doubled mount paths.
- Store cloud-init seed images where the virtualization service account can read them.
- Do not expose VNC/display listeners on all interfaces.
- Recycled addresses require host-key verification and deliberate known-host cleanup before reconnecting.

## Completion checks

Before declaring recovery complete, verify:

- cluster quorum and expected members;
- no failed services;
- guest state and HA ownership;
- storage availability on each intended node;
- successful replication with target datasets present;
- current PBS backup and remote-sync jobs;
- at least one tested restore path;
- no credentials, private addresses, node names, guest IDs, or device identifiers were written into tracked files.
