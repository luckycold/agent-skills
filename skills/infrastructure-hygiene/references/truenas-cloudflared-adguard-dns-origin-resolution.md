# TrueNAS Cloudflared / AdGuard DNS Origin Resolution

Use this when Cloudflare Tunnel reports an origin as unreachable even though the TrueNAS app itself is running. Resolve the private public host, internal origin, app wildcard, and AdGuard hostnames from `~/.agents/private-context.md`.

## Failure signature

Cloudflared logs show an internal origin name resolving to public Cloudflare edge IPs instead of the NAS, then timing out on the app port:

```text
originService=http://<private-internal-origin>:<port>
dial tcp 104.21.x.x:30041: i/o timeout
dial tcp 172.67.x.x:30041: i/o timeout
```

This means cloudflared/Docker DNS is resolving through public DNS, not the local AdGuard rewrite path.

## Diagnostic sequence

Run from the NAS over SSH:

```bash
midclt call app.query | jq -r '.[] | select(.name|test("adguard|cloudflared|immich|traefik")) | [.name,.state,.version] | @tsv'
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -Ei 'adguard|cloudflared|immich|traefik'
ss -tulpen | grep -E ':(53|80|443|30041|30069)\b' || true
midclt call network.configuration.config | jq '{nameserver1,nameserver2,nameserver3,domains}'
rc=$(docker inspect ix-cloudflared-cloudflared-1 --format '{{.ResolvConfPath}}'); sed -n '1,80p' "$rc"
for h in "$PRIVATE_INTERNAL_ORIGIN" "$PRIVATE_PUBLIC_HOST"; do dig +short @"$ADGUARD_IP" "$h" A; done
```

Also verify the app path independently:

```bash
curl -kIsS http://${NAS_IP}:30041/ | sed -n '1,8p'
curl -kIsS --resolve "$PRIVATE_PUBLIC_HOST:443:$TRAEFIK_IP" "https://$PRIVATE_PUBLIC_HOST/" | sed -n '1,8p'
```

If these are healthy but Cloudflared logs public Cloudflare IPs for the private internal origin, fix DNS rather than the app.

## Corrective pattern

1. Determine where AdGuard is actually publishing DNS:

```bash
docker ps --filter name=adguard --format '{{.Names}} {{.Ports}}'
ss -tulpen | grep ':53\b'
```

2. Point TrueNAS host DNS at that active listener. On Luke's NAS, the known-good state after the July 2026 outage was AdGuard DNS on `${REVERSE_PROXY_IP}:53`:

```bash
midclt call network.configuration.update '{"nameserver1":"${REVERSE_PROXY_IP}","nameserver2":"1.1.1.1","nameserver3":"9.9.9.9"}'
```

3. Ensure AdGuard rewrites return local origins:

```yaml
<private-internal-origin>: <backend-ip>
<private-app-wildcard>: <traefik-ip>
<private-public-host>: <traefik-ip>
```

Avoid bogus rewrite answers like `answer: A`; use concrete IPs/CNAMEs.

4. Restart AdGuard if the config file was edited directly, then cycle affected apps so Docker regenerates `/etc/resolv.conf`:

```bash
docker restart ix-adguard-home-adguard-1
midclt call -j app.stop cloudflared
midclt call -j app.start cloudflared
```

5. Verify cloudflared's resolver now contains the active AdGuard listener:

```text
ExtServers: [host(${REVERSE_PROXY_IP}) host(1.1.1.1) host(9.9.9.9)]
```

6. Verify externally and locally:

```bash
curl -kIsS "https://$PRIVATE_PUBLIC_HOST/api/server/ping" | sed -n '1,12p'
for h in "$PRIVATE_PUBLIC_HOST" "$PRIVATE_ADGUARD_HOST" "$PRIVATE_ADGUARD_LAN_HOST"; do
  curl -kIsS --resolve "$h:443:${REVERSE_PROXY_IP}" "https://$h/" | sed -n '1,8p'
done
```

## AdGuard via Traefik

If the private AdGuard host returns Traefik `404` while the direct backend returns `/login.html`, add a small dedicated Traefik dynamic route:

```yaml
http:
  routers:
    adguard:
      rule: "Host(`<private-adguard-host>`) || Host(`<private-adguard-lan-host>`)"
      entryPoints: [websecure]
      tls: {}
      priority: 100
      service: adguard

  services:
    adguard:
      loadBalancer:
        servers:
          - url: "http://${NAS_IP}:30069"
```

A nested private AdGuard hostname may still fail at Cloudflare TLS if the edge certificate does not cover that wildcard depth; local Traefik success proves the NAS route is correct.

## Durable pin: hosts file mounted in the cloudflared app

Use this so tunnel origins never depend on DNS (for example AdGuard per-/24 rate limiting makes Docker fall back to public DNS, which answers internal names with Cloudflare anycast IPs). The TrueNAS catalog app has no extra_hosts field, so mount a hosts file read-only over `/etc/hosts`; Docker then skips its own hosts file, and the value persists across catalog upgrades.

1. Back up: `midclt call app.config cloudflared > /root/labby-backups/<date>/app-config.json` (contains the tunnel token: `chmod 600`, never print it).
2. List origins from the last `Updated to new configuration` log line (token-mode tunnels are dashboard-managed; no local config.yml). Resolve every internal origin name, including short names expanded by the resolv.conf `search` domain, via AdGuard and pin the same answers.
3. Write `/mnt/<pool>/<apps-dataset>/cloudflared/hosts` (644; keep the `localhost` lines).
4. Apply (restarts the app once; open a Kuma maintenance window first):

```bash
midclt call -j app.update cloudflared '{"values":{"storage":{"additional_storage":[{"type":"host_path","read_only":true,"mount_path":"/etc/hosts","host_path_config":{"acl_enable":false,"path":"/mnt/<pool>/<apps-dataset>/cloudflared/hosts"}}]}}}'
```

5. Verify: `docker inspect <ctr> --format '{{json .Mounts}}'`, `docker cp <ctr>:/etc/hosts - | tar -xO` (image is distroless: no getent/shell), `/ready` readyConnections ≥ 1 on the container IP `:20241`, and 20+ requests via `curl --resolve host:443:<ip from 1.1.1.1>`.
6. Rollback: same update with `"additional_storage":[]`. When an origin IP changes, edit the hosts file and restart the app.

Removing a public hostname from a dashboard-managed tunnel needs the Zero Trust dashboard or an API token with Cloudflare Tunnel edit rights; the connector cannot do it locally.
