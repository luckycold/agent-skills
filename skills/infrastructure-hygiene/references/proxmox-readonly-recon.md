# Read-only Proxmox reconnaissance

Use this when Luke asks the agent to learn or diagnose a Proxmox host without changing it. Resolve targets, hostnames, addresses, and SSH-agent paths from the ignored `~/.agents/private-context.md` at runtime.

## Discovery before credentials

Start with low-impact observations:

- DNS resolution and reverse DNS.
- ICMP reachability where allowed.
- TCP checks for the web UI, SSH, and any reverse-proxy listener.
- TLS certificate subject, SAN, issuer, and expiry.
- Login-page asset versions to estimate the PVE release.
- Existing Home Assistant or network-controller inventory when already authorized.

Do not infer exact OS, cluster, guest, or storage state from unauthenticated hints. Label estimates clearly.

## Authenticated read-only inventory

Once trusted SSH is available, collect:

```bash
hostnamectl
cat /etc/os-release
pveversion -v
uname -a
pvecm status
pvecm nodes
pvesh get /cluster/resources --type vm --output-format json
pvesm status
zpool status
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
ip -brief address
ss -lntup
systemctl --failed
```

For each command, summarize only the operational facts needed for the current task. Do not publish or persist exact hostnames, private addresses, serial numbers, MAC addresses, guest IDs, usernames, certificate names, or storage topology in this public skill.

## Verification discipline

- Correlate cluster membership, quorum, guest placement, storage availability, and running kernel before recommending an upgrade or reboot.
- Distinguish userspace version from running-kernel version.
- Treat stale inventory as a hypothesis; re-read live state before administration.
- If a host is unreachable, separate DNS, routing, link, firewall, SSH, and service-layer failures.
- Stop at the read-only boundary unless Luke explicitly asks for a change.

For reusable cluster recovery, local-ZFS replication, Ceph retirement, and PBS patterns, see `proxmox-cluster-ceph.md`. Keep Luke's current topology only in private context, not in this repository.
