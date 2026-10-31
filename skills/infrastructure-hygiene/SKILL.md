---
name: infrastructure-hygiene
description: Luke's lab procedures that are easy to get wrong — UniFi port forward, DHCP/DNS, split-horizon, and IoT allowlist; Traefik/Authelia lockdown; TrueNAS ACME, pool space, ZFS dataset delete, Backrest, qbit_manage orphans, and RomM; HA SSH add-on (left on intentionally); tool approval versus chat approval; agent CLIs on LAN hosts. The router is DNS.
author: Luke
category: devops
---

# Infrastructure hygiene

Procedures for Luke's lab. Load `proxmox-homelab` for Proxmox itself and `truenas-custom-apps` for ix-apps registration, Proton Bridge, and per-app Traefik files.

## Tool approval is not chat approval

Destructive `rm`, `zfs destroy`, and `app.delete` can still require the runtime tool-confirmation prompt. Chat "approved / try again / do it" is not enough when the tool returns `BLOCKED: user has NOT consented`. Do not loop rephrases. Ask Luke to approve the next tool popup, then retry once.

## DNS

The router is DNS. AdGuard is opt-in for devices Luke names, not the NAS, Docker, or DHCP default. No public secondary. Do not rewrite app hostnames onto the NAS UI address. See [lab DNS](references/lan-dns.md).

## UniFi

Changes go through the Network API, not SSH on the gateway.

- [Port forwarding](references/unifi-port-forwarding-via-api.md)
- [DHCP, DNS, and IP diagnostics](references/unifi-dhcp-dns-via-api-and-ip-diagnostics.md)
- [Split-horizon DNS](references/unifi-split-horizon-dns.md) — forward domains, wildcard A does not block AAAA, turn Cloudflare ECH and IPv6 off before retiring a forward
- [IoT internet allowlist](references/unifi-iot-internet-allowlist-via-api.md)
- [Wired port native network](references/unifi-port-native-network.md)

## Traefik, Authelia, certificates

- Authelia by default, per-app API bypasses, tunnel-connector exclusions, and origin lockdown: [Traefik and Authelia lockdown](references/traefik-authelia-default-and-origin-lockdown.md).
- Renew with `certificate.renew_certs` as a job. A Cloudflare `Cannot use the access token from location` error is an IP-restricted token. See [ACME renewal](references/truenas-acme-renewal.md).
- Per-app route files and when to skip Authelia live in `truenas-custom-apps`.

## TrueNAS storage and apps

- Apps pool space: prune unused images first. [Space reclaim](references/truenas-apps-pool-space-reclaim.md).
- A dataset that will not delete: [dataset busy](references/truenas-zfs-dataset-busy-delete.md).
- Backrest and restic path health: [Backrest](references/truenas-backrest-restic-path-health.md). Consistent Postgres and SQLite dumps for those plans are `truenas-custom-apps` scripts `pg-dump-exec.sh` and `sqlite-dump.py`.
- qbit_manage: mirror the tracker-tag convention. Never raise the orphan threshold or delete orphans without a read-only manifest and hard-link audit. [Orphan forensics](references/truenas-qbit-manage-retention-and-orphan-forensics.md).
- RomM PS3 imports and multi-file folders: [PS3 imports](references/truenas-romm-ps3-imports.md), [folder ingest](references/romm-multifile-folder-ingest.md).

## Home Assistant

The SSH & Web Terminal add-on is intentionally left running; use it for `/config` work and don't stop it. Agent tokens cannot manage add-ons through the Supervisor API, so its state is Luke's call in the UI. HA is not a TrueNAS app. See [SSH access](references/ha-ssh-addon-temporary-access.md).

`<ha-hostname>.local` stuck renaming upward (`homeassistant8`) on a multi-VLAN host: see [mDNS hostname conflict](references/ha-mdns-hostname-conflict.md).

## Agent CLIs on LAN hosts

Headless Proxmox nodes stow `common` then `agent`; the praxis desktop VM keeps `personal`. On every host, skills install and refresh through skills.sh (`npx skills add luckycold/agent-skills`), which `update-agent-skills` wraps. Keep binaries and auth outside Stow. Do not install glibc CLIs into the Alpine SSH add-on or onto the HAOS root. See [agent CLIs](references/agent-clis-lan-hosts.md).

Local Proton mail on an Arch agent host (packaged Bridge user service plus Himalaya; verify the actual sent message, not a pre-send Sent copy): see [local Proton mail on Arch](references/local-proton-mail-arch.md).

## Other

- NetBird routed networks that fail only when Wi-Fi and Ethernet are both up: [dual-homed workstation](references/netbird-bmc-work-pc-dual-homed.md).
- Standalone Raspberry Pi OTBR for Home Assistant: [OTBR](references/rpi-otbr-docker-appliance.md).

## Self-maintenance

This is a Luke-authored personal skill. After a verified correction, update this package under `~/.agents/skills/` with the smallest evidence-backed edit. Follow `personal-skill-maintenance`. Do not record secrets or transient state.
