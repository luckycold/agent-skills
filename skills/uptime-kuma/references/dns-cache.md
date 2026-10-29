# Local DNS cache for the Kuma CT

## Why

The router is lab DNS. UniFi local records answer with **TTL 0**, so without a cache every check re-queries the router. AdGuard is opt-in for devices Luke names. Do not forward Kuma, the NAS, or DHCP at AdGuard, and do not use a public resolver. A public answer for an internal name is a Cloudflare address and breaks tunnel origins.

The cache was first added while AdGuard was still the resolver (per-/24 rate limit, rewrite TTL 10 s). That resolver is retired for the lab. Keep the cache; point it at the router.

## Setup (inside the CT)

1. `apt-get install unbound` (Debian package, covered by unattended-upgrades). systemd drop-in `Restart=always`.
2. `/etc/unbound/unbound.conf.d/labby-kuma-dns.conf`:
   ```
   server:
       interface: 127.0.0.1
       interface: <bridge-gw>            # the .1 of the fixed Docker bridge subnet
       ip-freebind: yes                  # bind before Docker creates the bridge
       do-ip6: no
       access-control: 0.0.0.0/0 refuse
       access-control: 127.0.0.0/8 allow
       access-control: <bridge-subnet> allow
       module-config: "iterator"         # no DNSSEC: LAN answers must pass
       cache-min-ttl: 600
       serve-expired: yes
       serve-expired-ttl: 86400
       serve-expired-client-timeout: 1800
       prefetch: no
   forward-zone:
       name: "."
       forward-addr: <router>            # lab DNS, never AdGuard and never public DNS
   ```
3. Compose: a named network with fixed `ipam` subnet/gateway, and `dns: [<bridge-gw>, <router>]` (the router is the fallback if unbound is down). Recreate inside a maintenance window.

## Verify

- `docker exec uptime-kuma getent hosts <route-host>` returns the proxy IP; `unbound-control stats_noreset | grep total.num`.
- The container `/etc/resolv.conf` `# ExtServers:` line lists the bridge gateway and the router.
- Querying `<bridge-gw>` from the CT host itself returns REFUSED (access-control allows the bridge subnet and loopback). Test from inside the container or via 127.0.0.1.
- Trade-off: Kuma sees a local-record change up to 10 minutes late. Lower `cache-min-ttl` if that matters.
