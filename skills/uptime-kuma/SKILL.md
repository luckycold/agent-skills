---
name: uptime-kuma
description: Build, extend, tune, and maintain Luke's self-hosted Uptime Kuma v2 availability monitoring (Docker in a small Proxmox LXC) with meaningful app-level health checks, push monitors fed by read-only host scripts, a webhook to the agent responder, a dead-man heartbeat, and self-maintaining updates/backups. Use for any "monitor/uptime/health check/alert on my apps" task or when a Kuma alert needs triage.
author: Luke
category: devops
---

# Uptime Kuma (lab availability monitoring)

Resolve the real CT id, IPs, URLs, Pass item names, and monitor inventory from `~/.agents/private-context.md` (section **Uptime Kuma**) and the private notes it points to. This skill uses placeholders: `<kuma-ip>`, `<kuma-ct>`, `${NAS_IP}`, `${REVERSE_PROXY_IP}`.

Load with: `proxmox-homelab` (access, quorum rules), `truenas-custom-apps` / `infrastructure-hygiene` (apps, Traefik, Authelia), `proton-pass-cli` (secrets), `ntfy-ops`.

## Rules

- Monitoring must be **read-only** against the lab. Host-side push scripts may read state (`zpool status -x`, `midclt call app.query`, `pvesh get`, `docker ps`, a `SELECT` in an app DB) but never change it.
- Prefer checks on the LAN address of each app (bypassing Traefik), plus a separate Traefik check per route. For Authelia-gated routes, healthy = **302 with `auth.<domain>` in the body** (`maxredirects=0`, accepted `300-399`). Do not loosen Authelia rules or add bypasses for monitoring.
- Intentionally stopped apps are excluded by name (`EXPECTED_STOPPED`), never shown as failures. Ask Luke before adding one.
- **Every DOWN wakes the agent responder.** Before bulk create/edit/resync, run `scripts/maintenance.py start`; end with `stop`, then check `scripts/status.py` and send one test notification.
- Never store tokens in this repo. Admin login, metrics API key and push tokens live in Pass / root-only files on the hosts.

## Architecture

- Unprivileged Debian LXC on the primary Proxmox node, healthy non-worn storage, `onboot=1`, `features: nesting=1,keyctl=1`, Docker CE + compose, image `louislam/uptime-kuma:2` (pinned major), SQLite, data in `/opt/uptime-kuma/data`. Container DNS = a local **unbound cache in the CT** (compose network with a fixed subnet, `dns: [<bridge-gw>, ${ADGUARD_IP}]`), never a public resolver: AdGuard rate-limits per /24 and its rewrites have TTL 10 s, so uncached Kuma traffic starves other LAN hosts. Details: [references/dns-cache.md](references/dns-cache.md).
- Notification: one **Webhook** (JSON, `Authorization: Bearer <key>`), `isDefault` + `applyExisting`, attached to every monitor.
- Push monitors (interval 600 s) are fed every 5 min by `scripts/nas-kuma-push.sh` (TrueNAS cron job) and `scripts/pve-kuma-push.sh` (`/etc/cron.d`). Each script sources a root-600 `tokens.env` with `T_*` push tokens.
- Dead-man: `kuma-heartbeat.sh` in the CT pings an external URL (Healthchecks.io) from `/root/.heartbeat-url` every 2 min while Kuma is healthy. Without that external check, a dead pve/Internet is silent.

## Agent tooling (from the box over the home VPN)

```bash
cd <private-kuma-dir> && python3 -m venv venv && venv/bin/pip install "python-socketio[client]" websocket-client requests
export KUMA_URL=http://<kuma-ip>:3001 KUMA_PASS_ITEM_ID=<pass-item-id>   # login read from Pass, never printed
venv/bin/python status.py            # non-UP monitors with last message
venv/bin/python maintenance.py start # suppress alerts; ... edit spec / sync ...; maintenance.py stop
venv/bin/python sync.py              # upsert spec.py GROUPS by monitor name (idempotent)
```

`scripts/kuma.py` is a thin socket.io client (`emit(event, *args)`): events used are `login`, `setup`, `add`, `editMonitor`, `getMonitor`, `deleteMonitor`, `addNotification`, `testNotification`, `addMaintenance`, `addMonitorMaintenance`, `deleteMaintenance`, `addAPIKey`. First boot of v2 needs `POST /setup-database {"dbConfig":{"type":"sqlite"}}` before `setup`.
Keep the live `spec.py` (real hosts) in the private notes dir, not here. Monitor-type field names and gotchas: [references/check-design.md](references/check-design.md).

## Self-maintenance of the monitor

- `unattended-upgrades` for Debian, security, updates and the Docker CE origin; no auto-reboot. Docker json-file logs capped.
- `/root/update-kuma.sh` in the CT: pull the pinned major, SQLite `.backup`, recreate, wait for container `healthy` + `/api/entry-page` 200. Run from the weekly review, **not cron**. Ask Luke before a major-version change.
- Nightly vzdump of only the Kuma CT, snapshot mode. If the PBS token lacks `Datastore.Prune`, a `keep-last` job fails nightly after uploading; use `keep-all` until the ACL fix (DatastorePowerUser on the datastore, see `proxmox-homelab` backup-health) is approved, then switch to `keep-last 7`.

## Triage of an alert

1. `status.py` for the message. Push-monitor messages say exactly what failed (app name, pool, dump age).
2. Confirm on the host (read-only). A group DOWN only repeats its children.
3. If the check was wrong (keyword not in page, wrong encoding), fix `spec.py` and sync inside a maintenance window; record it as a false alarm for Luke.

## Self-maintenance

Luke-authored personal skill. Update it when a verified check pattern or fix recurs. Live values belong in private context; follow `personal-skill-maintenance` and run the public-safety check before committing.
