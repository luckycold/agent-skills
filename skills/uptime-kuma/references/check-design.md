# Meaningful health checks in Uptime Kuma v2

Prefer checks that prove the app's **dependencies** work (DB, upstream, auth), not just that a port is open.

## Field names (socket `add` / `editMonitor` payloads)

- HTTP status: `type=http`, `url`, `accepted_statuscodes` (e.g. `["200-299"]`, `["401"]`), `maxredirects`, `ignoreTls`, `expiryNotification` (TLS cert expiry).
- Keyword: `type=keyword`, `keyword`, `invertKeyword`. Plain substring of the first part of the body. Login pages often don't contain the product name (a login page whose title is `Login`; VueTorrent UI never says qBittorrent). **Verify the keyword with curl first.**
- JSON: `type=json-query`, `jsonPath` (JSONata), `expectedValue` (string), `jsonPathOperator` (`==`, `!=`, `contains`, ...). Example `$ in ['leader','router','child']` with expected `true`.
- DNS: `type=dns`, `hostname`, `dns_resolve_server`, `port=53`, `dns_resolve_type`, `conditions` = **list** `[{"type":"expression","andOr":"and","variable":"record","operator":"equals","value":"<ip>"}]`. Sending a JSON string double-encodes it → `conditions.forEach is not a function`.
- Port/ping: `type=port` (`hostname`, `port`), `type=ping`.
- Push: `type=push`, `pushToken` (any 32-char alnum you generate), interval ≥ 2× the script cadence. Script calls `GET /api/push/<token>?status=up|down&msg=...`.
- Group: `type=group`; children set `parent`. A group goes DOWN when any child is down (alerts twice).

## Patterns that worked (2026-10)

| App | Check | Proves |
|---|---|---|
| Immich | `/api/server/ping` res=pong; `/api/server/config` keyword `trashDays`; public URL `/api/server/version`; DB-dump push | server + DB-backed config + public route + backups. Sole Immich monitor (watchdog retired); crashes need a manual restart |
| FreshRSS | `/i/` keyword `tree-folder category`; `/api/greader.php` = OK; push: newest `<user>_entry.id` (µs) < 6 h | UI renders categories from DB; client API; feeds actually refresh |
| Plex | `/identity` keyword = expected `machineIdentifier` | right, claimed server |
| Home Assistant | `/manifest.json` keyword; `/api/` expects 401 | frontend + core API (200 needs a long-lived token) |
| Authelia | `/api/health` status OK | auth portal |
| *arr apps | `/ping` status OK | app + DB |
| n8n | `/healthz/readiness` status ok | DB connected |
| Jellyfin | `/health` = Healthy | |
| ntfy | `/v1/health` healthy=true | |
| Home DNS (the router) | `type=dns` against the router: a local record equals its LAN IP (e.g. NAS host, proxy wildcard) + an external name | local records + upstream |
| cloudflared | host push: container IP `:20241/ready` readyConnections ≥ 1 | tunnel connected |
| Public path | host push: `curl --resolve host:443:<ip from 1.1.1.1>` | Cloudflare → home works (bypasses home DNS) |
| Thread OTBR on isolated VLAN | host push via `qm guest exec <vmid> -- curl 127.0.0.1:8081/node/state` | border router role |
| TrueNAS | push: `zpool status -x`, `app.query` states, `alert.list` CRITICAL/ERROR, unhealthy containers; API 401 = middleware up | pools, apps, SMART/cloud-sync alerts |
| Proxmox | push: `pvecm status` Quorate, onboot guests running, replication `fail_count`/`last_sync`, vzdump `ctime` per vmid, `pvesm status` | cluster, guests, backups |
| Backups | push: newest dump age/size/sha1, HA backup file age | backups are fresh, not just jobs scheduled |

## Gotchas

- In host scripts, inline `python3 -c '...'` inside bash: don't use backslash-escaped quotes inside f-strings (Python < 3.12 SyntaxError). A failing parser must turn the check **down** (`|| bad=check-failed`), never silently up.
- Never run push scripts with `bash -x`: it prints push tokens.
- TrueNAS `cronjob.create` fields are `stdout`/`stderr` (true = hide), not `hide_stdout`.
- Kuma's own DNS is the home resolver (via the CT's unbound cache), so `*.domain` checks hit Traefik on the LAN; use host pushes for the public path. A public fallback resolver makes `*.domain` checks silently go to Cloudflare IPs when the home resolver drops a query.
- `type=dns` monitors use their own resolver (`dns_resolve_server`) and bypass the container DNS/cache, so home-DNS checks stay real.
- If the home resolver has no split-horizon record for a public name (it returns the CDN IPs), say so in the check description and expect only what the public path returns (e.g. the app's version JSON), not a LAN-only detail. Retired checks: pause, list their IDs in the spec, keep them out of the synced groups.
- Kuma has no alert dependencies: a NAS outage fires one alert per monitor. Keep LAN-direct checks critical and route checks at 5 min.
