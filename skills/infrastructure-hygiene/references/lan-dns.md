# Lab DNS

The router is DNS. AdGuard Home is opt-in for devices Luke names. It is not the resolver for the NAS, Proxmox, Docker, Uptime Kuma, or LAN DHCP.

Local names live on the UniFi gateway. Record shape, wildcard A versus AAAA/HTTPS, and retiring an old forward are in [UniFi split-horizon DNS](unifi-split-horizon-dns.md). DHCP and the controller API are in [UniFi DHCP and DNS](unifi-dhcp-dns-via-api-and-ip-diagnostics.md).

## Addresses that stay distinct

- `${NAS_IP}` is the TrueNAS UI. It is not the DNS listener and not the app route.
- `${REVERSE_PROXY_IP}` is Traefik on 80/443. Do not rewrite private app hostnames from Traefik onto the NAS UI address. That bypasses Traefik and Authelia.
- Names that must not follow the app wildcard (PBS and similar) are exact UniFi records, not AdGuard rewrites.

## TrueNAS host resolver

`nameserver1` is the router. Leave `nameserver2` and `nameserver3` empty.

```bash
midclt call network.configuration.update '{"nameserver1":"<router>","nameserver2":"","nameserver3":""}'
```

A public secondary answers internal names with Cloudflare anycast. Cloudflared then dials `104.21.x.x` or `172.67.x.x` and times out on the app port. Do not add `1.1.1.1` or `9.9.9.9`, and do not point the host at AdGuard so catalog sync works at boot.

## Stale Docker DNS

Containers keep the upstreams captured at create time:

```text
nameserver 127.0.0.11
# ExtServers: [host(<nameserver1>)]
```

After a host resolver change, `midclt call -j app.redeploy <app>`. This stack has no `app.restart`. A healthy local port does not prove container DNS: Plex can answer `:32400` while `plex.tv` fails inside the container until that app is redeployed.

## Checks

- `dig` against the router returns LAN addresses for internal names, not Cloudflare.
- A container's `ExtServers` line is the router only.
- `curl --resolve <host>:443:${REVERSE_PROXY_IP}` checks the Traefik route. That is a different question from which server answered DNS.

Before repointing clients, compare the new resolver with the old one for proxied names, wildcards, and short names. Stop if an internal name comes back as a public address. Docker apps keep the old `ExtServers` until each one is redeployed.
