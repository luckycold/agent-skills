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
  gated. Report these rather than changing them silently; app clients may depend on them.

## 2. Docker hairpin pitfall (tunnel traffic looks internal)
A container (for example `cloudflared`) that connects to Traefik's *host-published* IP arrives
through docker-proxy with the **Docker network gateway** as its source address. If Authelia
bypasses that subnet by network, every request through that tunnel skips Authelia.
Verify in Traefik's access log (the client column) before trusting a tunnel → Traefik route.
Fixes: point that hostname at the normal proxied-DNS path (Cloudflare → WAN → Traefik), use a
tunnel connector running outside that Docker host, or narrow the network bypass.

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

## Rollback pattern
Keep `*.bak-<date>-<agent>` beside every edited dynamic file, a tarball of the dynamic dir and
the app config JSON, and a JSON snapshot of the tunnel configs and DNS records. Remove the
entrypoint args before deleting the allowlist file, otherwise every router errors.
