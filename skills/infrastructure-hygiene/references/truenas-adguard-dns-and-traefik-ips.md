# TrueNAS AdGuard DNS binding vs Traefik app routing

Session-derived note for Luke's TrueNAS SCALE host (`${NAS_IP}`) where the same host also carries the legacy/secondary service IP `${REVERSE_PROXY_IP}`.

## Topology observed

- Host bridge `br0` has both `${NAS_IP}/23` and `${REVERSE_PROXY_IP}/23`.
- TrueNAS UI/nginx listens on `${NAS_IP}:80/443`.
- Traefik app listens on `${REVERSE_PROXY_IP}:80/443`.
- AdGuard Home web UI listens on `${NAS_IP}:30069`.
- **DNS:** Luke also uses **`${REVERSE_PROXY_IP}` as an alternate DNS IP** on the NAS (same `br0` host). Verify live with `dig @${REVERSE_PROXY_IP}` and `dig @${NAS_IP}` — publish/bind may differ by app config over time. Do not tell Luke ".0.2 is not DNS" from Traefik notes alone.
- AdGuard DNS is often published on `${NAS_IP}` when DHCP should hand clients that IP first.
- AdGuard rewrites for the private app wildcard intentionally send HTTPS app hostnames to Traefik, not to the TrueNAS UI. Resolve exact names and addresses from `~/.agents/private-context.md`.
- Hosts that must **not** land on Traefik need an **exact** rewrite that wins over `${PRIVATE_APP_WILDCARD}` → `${REVERSE_PROXY_IP}`. Verified: `${PRIMARY_BACKUP_HOSTNAME}` → hypervisor PBS and `${SECONDARY_BACKUP_HOSTNAME}` → the TrueNAS PBS VM. Edit `/mnt/Apps/Applications/adguard-home/config/AdGuardHome.yaml` `filtering.rewrites`, then **restart** `ix-adguard-home-adguard-1`. `SIGHUP` does not reload that YAML.

## Important pitfall

Do **not** blindly rewrite private app hostnames from the Traefik address to the NAS UI address just because apps and DNS share the NAS. That would bypass Traefik/Authelia and likely break routes unless Traefik is also moved.

## Safe update pattern for AdGuard DNS bind IP

1. Inspect current app config:
   ```bash
   midclt call app.config adguard-home | jq '.network'
   ```
2. Update only `network.dns_port.host_ips` via TrueNAS middleware, preserving the rest of the app config. Avoid editing rendered compose files directly.
3. Example pattern:
   ```bash
   python3 - <<'PY'
   import json, subprocess
   app = 'adguard-home'
   cfg = json.loads(subprocess.check_output(['midclt', 'call', 'app.config', app]))
   cfg['network']['dns_port']['host_ips'] = ['${NAS_IP}']
   cfg.pop('ix_context', None)
   open('/tmp/adguard-update-values.json', 'w').write(json.dumps({'values': cfg}))
   PY
   midclt call -j app.update adguard-home "$(cat /tmp/adguard-update-values.json)"
   ```
4. Verify:
   ```bash
   midclt call app.query '[["name","=","adguard-home"]]' | jq -r '.[0].state'
   ss -H -ltnup '( sport = :53 or sport = :30069 )'
   dig +time=1 +tries=1 +short @"$DNS_IP" "$PRIVATE_DNS_HOST" A
   ```

## Verification distinction

- `dig @${NAS_IP} <host> A` verifies the DNS service is reachable at the requested DNS IP.
- `curl --resolve "$PRIVATE_APP_HOST:443:$TRAEFIK_IP" "https://$PRIVATE_APP_HOST/"` verifies Traefik app routing.
- Resolving the same host to the NAS UI address will likely hit TrueNAS nginx/UI instead of Traefik; that is evidence **not** to change DNS rewrites without moving Traefik.

## UniFi split DNS: check AAAA and HTTPS as well as A

An IPv4-only UniFi wildcard override can return the local app address for `A` while forwarding `AAAA` and `HTTPS` queries upstream. Public IPv6 addresses and HTTPS address hints can send a browser to Cloudflare even on home Wi-Fi. A successful IPv4 curl alone does not prove the browser uses the local route.

1. Compare `A`, `AAAA`, and `HTTPS` answers for the affected app **and its authentication hostname**, querying both `${GATEWAY_DNS_IP}` and `${ADGUARD_DNS_IP}` explicitly.
2. If AdGuard already gives the intended local `A` and NOERROR with no answers for `AAAA`/`HTTPS`, use UniFi's native **Forward Domain** policy for the affected hostname, or the app domain after the loop checks below, targeting AdGuard. This preserves network-wide DHCP and IPv6 settings. Back up existing policies first; preserve unrelated records.
3. The verified UniFi Network endpoint is `/proxy/network/v2/api/site/<site>/static-dns`. Forward Domain records use `record_type: "NS"`, `key: "<affected-hostname>"`, `value: "<adguard-dns-ip>"`, and `enabled: true`. Inspect existing records before creating one. Use the authenticated session and CSRF token without printing or committing either.
4. Allow gateway provisioning to complete before judging the result. A newly saved policy can initially retain public answers; inspect again after provisioning. Require a local `A`, no public `AAAA` or `HTTPS` hints, valid TLS, and the expected app/authentication response.
5. Avoid forwarding an entire domain to AdGuard without checking its upstream configuration. If AdGuard sends unresolved names back to the gateway, this can create a DNS loop. Prefer narrowly scoped app/authentication forwarding when broader delegation is unnecessary. When multiple apps in the domain are affected, configure an AdGuard domain-specific public upstream such as `[/<app-domain>/]<public-dns-ip>` **first**, then delegate the domain from UniFi to AdGuard. Existing AdGuard wildcard/exact rewrites still supply local app addresses, while public apex/mail records resolve without looping. If changing the YAML directly, stop AdGuard through TrueNAS middleware, back up the stopped configuration privately, change only `dns.upstream_dns`, and restart it; require the app and container to be healthy before proceeding. Reuse an existing disabled Forward Domain policy where appropriate, updating its stale destination. Remove only redundant per-host policies created by the same repair. Verify representative app `A`/`AAAA`/`HTTPS` answers, apex `A` and `MX`, intentional public CNAME exceptions, exact local overrides, and unrelated internet DNS.
6. Browser caches can retain old DNS answers or connections after the server-side fix. Reopen the browser or reconnect Wi-Fi before retesting. If it still reaches Cloudflare, check Android Private DNS, browser Secure DNS, and VPN resolver settings rather than assuming the LAN policy covers them.

For a Cloudflare Error 1027, distinguish the separate Worker quota failure from the LAN routing fault: the Workers Free account allowance is 100,000 requests per day and resets at midnight UTC. Confirm the current limit in official documentation. A DNS-edit token does not establish access to Worker routes or analytics; require appropriately scoped authenticated access before attributing quota exhaustion to a particular Worker or traffic source. Do not change billing or public routes based only on the error page.

References: [UniFi DNS policies](https://help.ui.com/hc/en-us/articles/15179064940439-UniFi-DNS-Records-and-Local-Hostnames), [AdGuard domain-specific upstreams](https://adguard-dns.io/kb/adguard-home/configuration/#specifying-upstreams-for-domains), [Cloudflare Workers limits](https://developers.cloudflare.com/workers/platform/limits/).

## AdGuard DNS IP vs Traefik app IP (formerly in SKILL.md)

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

On Luke's TrueNAS host, distinguish the DNS service IP from the Traefik app-routing IP before changing DNS/app records:

- If Luke asks for the DNS server to be `${NAS_IP}`, update the TrueNAS-managed `adguard-home` app `network.dns_port.host_ips` via `midclt call -j app.update`, not rendered compose files.
- Do **not** blindly change app hostname rewrites from the private app wildcard/route host to the NAS UI address: on this host, the private context distinguishes Traefik's address from the TrueNAS nginx/UI address.
- If TrueNAS Apps show Docker DNS failures such as `lookup ... on 127.0.0.11:53: server misbehaving` or cloudflared resolves a private internal origin to public Cloudflare IPs, check the **TrueNAS host** resolver and the actual AdGuard published listener together. The safe invariant is: `midclt call network.configuration.config.nameserver1` must point at the IP where the `adguard-home` app actually publishes port 53. Resolve exact domains and addresses from `~/.agents/private-context.md`. After changing host DNS or app DNS binding, redeploy/restart affected apps so containers regenerate `/etc/resolv.conf`.
- Verify separately: `dig @${NAS_IP} <host> A` for DNS reachability, and `curl --resolve <host>:443:${REVERSE_PROXY_IP} https://<host>/` for Traefik routing.
- See `references/truenas-adguard-dns-and-traefik-ips.md` for the safe update command pattern and verification checklist.
- See `references/truenas-docker-dns-recovery.md` for the Authelia/Cloudflared/Traefik outage recovery pattern when bad host DNS propagates into Docker's embedded resolver.
- See `references/truenas-cloudflared-adguard-dns-origin-resolution.md` for the private photo-service class: a cloudflared internal origin resolves publicly because TrueNAS/Docker DNS points at the wrong AdGuard listener.
- See `references/truenas-plex-docker-dns-recovery.md` for the Plex-specific pattern: local Plex port healthy but MyPlex/remote unavailable because the container still has stale Docker `ExtServers`; verify container `plex.tv` DNS and redeploy Plex/related apps through TrueNAS.
- See `references/truenas-ninerouter-9router-maintenance.md` for Luke's `ninerouter` / 9Router custom app update pattern: migrate away from old copied `/app` runtime mounts, use the official `decolua/9router:latest` image, preserve `/app/data`, and verify `/api/version` plus the private route domain from the private context.
