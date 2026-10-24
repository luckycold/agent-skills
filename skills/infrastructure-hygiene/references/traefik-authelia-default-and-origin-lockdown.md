# Authelia by default + origin lockdown (Traefik behind Cloudflare)

Use when Luke asks to close public exposure, put Authelia "in front of everything", or stop
clients reaching Traefik without going through Cloudflare. Generic: resolve hosts, IPs and
tunnel IDs from private context / live config, never from this file.

## 1. Inventory every public path, not just Traefik routers
- **Traefik routers:** file provider *and* Docker labels. A label router without middleware is
  usually shadowed by a priority-100 file router for the same host, but not always.
  Run an audit (template below) instead of eyeballing.
- **Cloudflare Tunnel ingress:** remotely managed tunnels can send a hostname straight to an app
  or a UI (for example `https://<nas-ui-host>`), skipping Traefik and Authelia entirely. Read every
  tunnel's config via the Cloudflare API: `GET /accounts/{acct}/cfd_tunnel`, then
  `.../cfd_tunnel/{id}/configurations`. Match DNS CNAMEs (`<id>.cfargotunnel.com`) to tunnels.
  The `cloudflared` container log line `Updated to new configuration` also shows it.
- **DNS:** a DNS-only (grey-cloud) apex/A record publishes the home IP. A proxied wildcard
  CNAME to that apex still reaches the origin through Cloudflare.
- **Authelia `access_control`:** read the rules. A domain-wide `resources: ^/api...` bypass, or
  a `networks:` bypass for the Docker proxy subnet, quietly un-protects routes that look
  gated. Report these and get Luke's OK before changing them; app clients may depend on them.
  Section 6 covers how to replace them.

## 2. Docker hairpin pitfall (tunnel traffic looks internal)
A container (for example `cloudflared`) that connects to Traefik's *host-published* IP arrives
through docker-proxy with the **Docker network gateway** as its source address. If Authelia
bypasses that subnet by network, every request through that tunnel skips Authelia.
Verify in Traefik's access log (the client column) before trusting a tunnel → Traefik route.
Fixes: point that hostname at the normal proxied-DNS path (Cloudflare → WAN → Traefik), use a
tunnel connector running outside that Docker host, or narrow the network bypass.
The same gateway address is also what *every* app on that Docker host shows when it calls a
public hostname that resolves to Traefik's host IP. So a subnet bypass doubles as an
"anything on the NAS" bypass.

## 3. Default Authelia: per-router + audit, not entrypoint forwardAuth
Entrypoint-level forwardAuth (`--entrypoints.websecure.http.middlewares=authelia@file`) cannot be
opted out per router. Authelia rules match domain/path/method/network but **not headers**, so
header-based native-client routers (Jellyfin token routes) would break. Prefer:
- `middlewares: [authelia@file]` on every router, plus an explicit, commented bypass list
  (Authelia portal, apps with mobile/API clients, deliberately public services).
- **Override Docker label routers** with a file router at a higher priority (e.g. 150) that adds
  Authelia. Point it at a **file-defined service** (host IP:port or container name), not
  `<svc>@docker`. On startup the file provider loads first. A missing `@docker` service drops
  the override router, and the unauthenticated label router underneath then serves traffic
  (fail-open).
- Keep Kuma health checks working with narrow `Host && Method(GET) && Path(<health>)` routers at
  a higher priority, only for endpoints that leak nothing. If the "health" path is the SPA
  shell, convert the monitor to an Authelia-gate check (`maxredirects: 0`, `300-399`, keyword
  `auth.<domain>`).
- An audit script that walks file + label routers, treats a router as protected when it, or a
  higher-priority plain-Host Authelia router for the same host, has Authelia, and exits 1 for
  anything not on the bypass list. Self-test it by removing one bypass entry.

## 4. Restrict the origin to Cloudflare + private ranges
- First confirm how certificates renew. DNS-01 (for example TrueNAS ACME with a Cloudflare DNS
  authenticator) is unaffected. HTTP-01 on port 80 would break if only Cloudflare can reach it.
- Create an `ipAllowList` middleware file (Cloudflare `ips-v4` + `ips-v6`, RFC1918, loopback,
  `100.64.0.0/10`, ULA) **before** referencing it. Then attach it to the `web` and `websecure`
  entrypoints. On the TrueNAS Traefik catalog app, append `traefik.additional_args` flags
  `--entrypoints.<ep>.http.middlewares=<name>@file` via `midclt call -j app.update` (it restarts
  Traefik). Default `ipAllowList` uses the TCP peer address. Don't set `ipStrategy.depth` with
  untrusted XFF.
- Proxy (orange-cloud) the apex record. Leave mail/other non-HTTP DNS-only records alone.
  Prefer this over editing the router's port forward.

## 5. Verify from outside
- Through Cloudflare: each locked host → `302` to `auth.<domain>`. Bypassed apps → their own
  health 200. Authelia `/api/health` 200, and a bogus `/api/firstfactor` POST → 401.
- Direct to the home IP: use an **IP-literal URL with a Host header**
  (`curl -k -H 'Host: x' https://<wan-ip>/`). Expect Traefik's `403 Forbidden`. A sandbox with a
  transparent SNI proxy may silently send `--resolve` tests through Cloudflare instead. Confirm
  the source IP in Traefik's access log.
- Kuma: all monitors green after the change.

## 6. Replace blanket Authelia bypasses with per-app API bypasses
Goal: web UIs stay behind Authelia, and native, mobile and desktop apps keep working against
their own auth.
- **Find real callers first.** Traefik access log (`--accesslog=true`) grouped by client,
  router and first two path segments. Grep app configs and SQLite DBs for public hostnames.
  Typical internal callers: *arr download clients → qBittorrent, *arrs → Prowlarr indexer links
  (`/<id>/api`, `/<id>/download`, not under `/api`), Seerr/Tautulli → Plex, FreshRSS → RSS-Bridge,
  Prowlarr → FlareSolverr, Home Assistant → *arr APIs.
- **Probe each host's `/api/` from outside before and after.** SPAs answer 200 with their shell,
  which hides nothing. Watch for apps that **trust private IPs**: requests via Traefik come from
  a private address, so the app sees them as local. qBittorrent's `AuthSubnetWhitelist` and
  Plex's `allowedNetworks` both do this. Through a path bypass, their API is fully open to the
  internet. Never bypass those hosts publicly.
- **Per-host path bypass only when** a real client uses the path **and** the app enforces its own
  auth on it. Examples: an API key or token (*arr, Tautulli, Mealie, Kavita, Sure, Seerr),
  Proxmox `/api2/json/` tickets or API tokens (official mobile app), FreshRSS
  `greader|fever|pshb.php`, or T3 Code `/api/`, `/ws`, `/.well-known/t3/`.
  Keep web-only admin UIs fully protected: the TrueNAS UI and API (no official app), pgAdmin,
  Kuma, n8n, LLDAP.
- **Signup endpoints stay gated.** Put a `two_factor` rule for `^/api/users/register` (Mealie
  with `ALLOW_SIGNUP`) or `^/api/v1/auth/signup` (Sure) *before* that host's bypass rule.
  First match wins.
- **Password endpoints that become reachable** (for example Proxmox `POST /api2/json/access/ticket`):
  add a higher-priority Traefik router for just that method and path. Give it
  `[authelia, rateLimit]` with `sourceCriterion.requestHeaderName: CF-Connecting-IP`. Traefik
  delays requests up to a short max delay before it returns 429, so a burst may show as
  throttling rather than 429s.
- **Internal-only callers:** scope by domain + `networks: [<gateway>/32, <gateway-v6>/128]` (+ path
  where possible). Never use the whole Docker subnet. Document that no tunnel hostname for those
  hosts may point at Traefik. Better long term: point those apps at the LAN address.
- **Drop leftover template paths** (for example MeshCentral `/meshagents`, `/control`,
  `/identity` on every host). `/control` silently opened AdGuard's API.
- **Audit:** extend the router audit to parse `access_control` (cut that section out first:
  `{{ secret }}` templates break `yaml.safe_load`). Flag any bypass on a wildcard/apex domain
  or with no domain, any `networks` entry wider than one address, and any host not on a
  commented allowlist. Add a `--selftest` that feeds a blanket rule and expects it flagged.
- **Apply:** back up the config, write a candidate file, then run
  `authelia validate-config --config <candidate>` inside the container. Compare its warnings
  with the live file's, then swap the files and restart. Verify:
  - Protected UIs → 302; bypassed APIs → the app's own 401 or JSON.
  - Hairpin source (`docker exec <app> curl https://<protected-host>/`) → 302.
  - Internal callers' log lines are still 200, and Kuma is green.

## 7. Trusted LAN skips Authelia (when Luke treats the home LAN as safe)
- **Know what Authelia sees.** With no `forwardedHeaders.trustedIPs` on the entrypoints, Traefik
  drops incoming `X-Forwarded-*`, so forwardAuth's XFF is the TCP peer. Prove it: send a spoofed
  `X-Forwarded-For: <lan-ip>` through Cloudflare and over a VPN, then read Authelia's `remote_ip`
  log field. Don't trust Cloudflare's XFF to get real client IPs. Authelia uses the leftmost
  entry, which the client controls.
- **Map every source:** LAN clients through Docker DNAT keep their real address. Containers and
  a containerized cloudflared on the Traefik host show up as the Docker gateway. A
  **cloudflared connector running on another LAN host shows up as that LAN host's IP**. So its
  tunnel traffic would match a LAN rule. VPN and VLAN clients may be routed (own subnet) or
  NATed (router IP); check the access log.
- **Rule order:** per-host API bypasses → internal hairpin rules → `two_factor` for each LAN
  tunnel-connector IP and the uptime monitor (so gate checks still see the 302) →
  `bypass` with `networks: [<lan-cidr>]` on the wildcard domains. Keep Tailscale, VPN, IoT and
  work VLANs out unless Luke says otherwise.
- **Audit:** allow one LAN-wide network rule only when every network is inside the configured LAN
  CIDRs **and** an earlier `two_factor` rule for the same domains lists every required exclusion.
  Selftest both failure modes.
- **Test:** LAN host with local DNS → app response, not Authelia. Box through Cloudflare with
  spoofed XFF → 302. Each real tunnel hostname → 302 (check `remote_ip`). Hairpin from a container
  → 302.
- Prefer removing tunnel → Traefik paths over relying on a fixed DHCP address. To do that:
  - Repoint the hostname's CNAME from `<tunnel-id>.cfargotunnel.com` to the proxied apex. Do this
    first, so there's no downtime.
  - Then trim the tunnel's ingress (keep the `http_status:404` catch-all).
  - Only then drop the connector host from the login-required rule.
  - Check that `remote_ip` changes from the connector's address to a Cloudflare edge IP.
- Make the audit enforce it. Keep a no-secrets snapshot of every tunnel's ingress from the
  Cloudflare API, with a stale warning, and a map of tunnel → connector location (LAN IP,
  Docker gateway, off-site, unknown). Fail on:
  - an unclassified tunnel;
  - a LAN-host connector that routes to Traefik while its IP isn't login-required;
  - an unknown-host connector that routes to Traefik.

## Rollback pattern
Keep `*.bak-<date>-<agent>` beside every edited dynamic file, a tarball of the dynamic dir and
the app config JSON, and a JSON snapshot of the tunnel configs and DNS records. Remove the
entrypoint args before deleting the allowlist file, otherwise every router errors.
