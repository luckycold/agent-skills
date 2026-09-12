# Raspberry Pi OpenThread Border Router (standalone Docker)

Minimal, maintainable OTBR for Home Assistant when OTBR runs on a dedicated Raspberry Pi (Ethernet) rather than as a Home Assistant OS add-on.

## Target shape

- Raspberry Pi OS Lite (64-bit / Trixie+)
- Static Ethernet addressing (resolve the intended host/IP from `~/.agents/private-context.md`)
- Docker host-network container: `ghcr.io/d34dc3n73r/ha-otbr:stable`
- REST API on host port **8081** (required by the Home Assistant OTBR integration)
- Optional Web UI on **8080**
- USB RCP (Connect ZBT-1 / SkyConnect / compatible) bound via `/dev/serial/by-id/...`

## Debian Trixie package pitfall (verified)

On Raspberry Pi OS / Debian Trixie, do **not** install `docker-compose-v2` (package missing). Install:

```bash
apt-get install -y --no-install-recommends docker.io docker-cli docker-compose usbutils
```

- `docker.io` provides `dockerd` but **not** always the `docker` CLI on this split.
- `docker-cli` provides `/usr/bin/docker`.
- `docker-compose` provides the Compose v2 CLI plugin (`docker compose` / `/usr/bin/docker-compose`).

## ghcr.io pull pitfall (verified)

If `docker compose pull` times out on `https://ghcr.io/v2/` while `curl -4 https://ghcr.io` works, Docker is often preferring broken IPv6. Prefer IPv4 for address selection:

```bash
echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
systemctl restart docker
```

Then retry `docker compose pull`.

## Compose essentials

- `network_mode: host`
- `privileged: true` (or equivalent caps + `/dev` access) on a dedicated appliance
- `BACKBONE_IF=eth0` for Ethernet-only Pi
- `DEVICE=/dev/serial/by-id/<stick>`
- `OTBR_REST_PORT=8081`
- Persist Thread state under a host bind such as `/opt/otbr/data` → `/data/thread`
- ZBT-1 / SkyConnect defaults that worked: `BAUDRATE=460800`, `FLOW_CONTROL=1`

## First-boot ordering

Avoid `Requires=` on a one-shot first-boot unit that later becomes inactive. Prefer:

- Idempotent first-boot script that exits 0 when a done-flag exists
- `Wants=` / `After=` from the OTBR unit
- Radio detect script that writes `device.env` from `/dev/serial/by-id` before `compose up`

## Home Assistant

1. Confirm REST: `curl http://<otbr-host>:8081/node` (expect JSON; `State` may be `disabled` until a network is formed).
2. Settings → Devices & services → Add **OpenThread Border Router** → `http://<otbr-host>:8081`.
3. Prefer forming/joining the Thread network from Home Assistant when replacing an older border router so credentials stay consistent with Matter.

## DNS hygiene

If AdGuard (or similar) has a wildcard rewrite for the private LAN zone pointing at the reverse proxy, add **exact** A rewrites for the OTBR hostname **above** the wildcard, then reload/restart the resolver. Exact entries without `enabled: true` may be ignored depending on config schema.

## Auto-updates (verified)

Keep the appliance hands-off with two mechanisms:

1. **OS:** install `unattended-upgrades` and enable daily apt periodic upgrades for Debian + Raspberry Pi Foundation origins. Prefer automatic reboot in a quiet window (e.g. `04:30`) when a reboot is required.
2. **OTBR image:** a systemd timer (e.g. daily ~`03:15` with randomized delay) running a small `/usr/local/sbin/otbr-update` that does `docker compose pull` then `docker compose up -d --remove-orphans` and prunes dangling images. Log to `/var/log/otbr-update.log`. On pull failure, leave the running container unchanged.

Do not add Watchtower unless there is a concrete need; a oneshot timer matches a single-compose appliance and avoids another long-running container.

3. **Radio / REST recovery:** keep a systemd path unit on `/dev/serial/by-id` that force-recreates the compose service on hotplug, plus a 1-minute health timer: if an RCP is present but `http://127.0.0.1:8081/node` fails, force-recreate. The OTBR process can die on USB I/O errors while the container stays "Up".

## Operations

```bash
# Radio rebind after hotplug
sudo otbr-detect-radio && sudo systemctl restart otbr

# Manual updates
sudo unattended-upgrade
sudo /usr/local/sbin/otbr-update

# Logs
sudo docker logs -f otbr
journalctl -u otbr-update.service -n 50
```

## Dedicated Ubuntu/Proxmox appliance variant

- Prefer the official `openthread/border-router` image and current upstream Docker documentation for a new generic Linux appliance; its `OT_RCP_DEVICE`, `OT_INFRA_IF`, and `/data` configuration differs from the community image above. Pin a verified image digest and confirm the running image ID.
- Identify USB vendor/product, physical port, and serial before exact-port Proxmox passthrough. Bind the guest `/dev/otbr-rcp` alias with a serial-specific udev rule; add the systemd tag and `SYSTEMD_WANTS=otbr.service` for late device arrival. Never pass all matching USB radios through.
- If USB enumeration succeeds but no serial port exists, test `modprobe cp210x`. Ubuntu minimal guests can lack the running kernel's `linux-modules-extra` package; install that guest package rather than changing hypervisor drivers.
- Probe the confirmed spare with official NabuCasa `universal-silabs-flasher` while OTBR is stopped. Working Spinel firmware needs no reflash. Verify actual RCP version and baud rate again through `ot-ctl rcp version` after starting OTBR.
- Read HA `thread/list_datasets`, then `thread/get_dataset_tlv` for the existing preferred dataset. Transfer credentials only in memory over encrypted stdin (Proxmox `qm guest exec --pass-stdin` supports this), PUT the complete TLV to local `/node/dataset/active` as `text/plain` while disabled, and compare every supplied TLV against readback without printing secrets. Enable via `/node/state` only after equality succeeds; never initialize a new dataset. Restrict the persistent state directory to root.
- Verify attachment to the existing extended PAN ID, neighbor connectivity, `ot-ctl br state`, and HA Core's own REST client reads. Discover HA's actual source interface before allowing its exact address through the guest REST firewall; do not assume the add-on namespace or main HA IP is the source for a dual-homed host.
- Exercise both service restart and guest reboot. Wait for Docker startup and mesh attachment before declaring failure; confirm restored router/child state, matching network identity, border routing, and HA REST reads after reboot. This does not prove physical unplug/replug recovery or full mesh failover.

## Related

- Private host/IP inventory: `~/.agents/private-context.md`
- HA OTBR integration docs: https://www.home-assistant.io/integrations/otbr/
