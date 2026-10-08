# Read-only infrastructure reconnaissance

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

When Luke asks you to "learn" an infrastructure host so you can help later, do an active but read-only orientation pass instead of waiting for credentials:

- Probe DNS, reachability, common service ports, TLS certificates, and unauthenticated status/API endpoints.
- Correlate with already-accessible systems such as Home Assistant device trackers, NAS reverse-proxy configs, and prior session records.
- In the Home Assistant add-on/container, expect network vantage to differ from the LAN. Use HA/UniFi device trackers for host/IP/MAC/name, then pivot through an already-trusted LAN host such as Proxmox for ARP, DNS, nmap, and port checks when container routing or mDNS is incomplete.
- For OS identification, prefer authenticated commands (`uname`, `/etc/os-release`, `sw_vers`) when SSH works. If SSH is filtered, use read-only network fingerprinting (`nmap -O -sV -Pn`) from a same-LAN host and label it as a confidence estimate rather than exact truth.
- Identify exactly what is still inaccessible because credentials are missing, host firewall blocks access, or the service is not enabled; recommend the cleanest future access path, such as enabling SSH for the known user or installing an authorized key.
- **Verify before blaming NAS/DNS:** Luke may use `${REVERSE_PROXY_IP}` as alternate DNS on TrueNAS; confirm with `dig`, not stale "Traefik-only" assumptions.
- **Work-from-home NetBird:** unstable private routed networks on home LAN with fine hotspot behavior → check dual-homed Wi‑Fi + Ethernet on the workstation; resolve private values from `~/.agents/private-context.md` and see `references/netbird-bmc-work-pc-dual-homed.md`.
- Save durable topology facts, but not raw credentials, private keys, cookies, or transient outage/error claims.

For Luke's Proxmox home lab (access, inventory, backup health), load the `proxmox-homelab` skill first. For generic Proxmox hosts, see `references/proxmox-readonly-recon.md` for the reusable inventory checklist and `references/proxmox-cluster-ceph.md` for generic quorum, upgrade, storage, replication, and PBS recovery patterns. Resolve Luke's current topology from private context. For workstation/laptop discovery from the HA add-on, see `references/laptop-lan-recon.md`. For NetBird → work BMC from home, see `references/netbird-bmc-work-pc-dual-homed.md`. For idempotent UniFi WAN port-forward creation with an API key, exact legacy endpoint/schema, credential hygiene, and external verification, see `references/unifi-port-forwarding-via-api.md`.
