# Local DNS cache for the Kuma CT

## Why
- AdGuard Home's default `ratelimit: 20` qps is per client **/24** (`ratelimit_subnet_len_ipv4: 24`). The Kuma CT shares a /24 with the NAS, so Kuma's lookups eat the NAS's budget; dropped queries made Docker on the NAS fall back to a public resolver, which answers internal names with Cloudflare IPs (broke the Cloudflare tunnel origin).
- AdGuard rewrites answer with **TTL 10 s**. Kuma's container runs `nscd` (Settings "nscd", on by default), but it honours that TTL and refreshes expired entries itself, so it barely helps (27 % hit rate; one query per name every ~15 s).
- Measured 2026-10-20: ~56 queries/min from the CT before. See the private notes for the after figure.

## Setup (all inside the CT; no AdGuard/router change)
1. `apt-get install unbound` (Debian package, covered by unattended-upgrades). systemd drop-in `Restart=always`.
2. `/etc/unbound/unbound.conf.d/labby-kuma-dns.conf`:
   ```
   server:
       interface: 127.0.0.1
       interface: <bridge-gw>            # e.g. the .1 of a fixed Docker bridge subnet
       ip-freebind: yes                  # bind before Docker creates the bridge
       do-ip6: no
       access-control: 0.0.0.0/0 refuse
       access-control: 127.0.0.0/8 allow
       access-control: <bridge-subnet> allow
       module-config: "iterator"         # no DNSSEC: rewrites to LAN IPs must pass
       cache-min-ttl: 600
       serve-expired: yes
       serve-expired-ttl: 86400
       serve-expired-client-timeout: 1800
       prefetch: no
   forward-zone:
       name: "."
       forward-addr: ${ADGUARD_IP}       # home resolver only, never public DNS
   ```
3. Compose: a named network with fixed `ipam` subnet/gateway, and `dns: [<bridge-gw>, ${ADGUARD_IP}]` (AdGuard direct is the fallback if unbound is down). Recreate inside a maintenance window; remove the old `<project>_default` network.

## Verify / measure
- `docker exec uptime-kuma getent hosts <route-host>` returns the proxy IP; `unbound-control stats_noreset | grep total.num`.
- `timeout 300 tcpdump -nn -l -i eth0 'udp dst port 53'` in the CT, count per minute and by name.
- Trade-off: Kuma sees an AdGuard rewrite change up to 10 min late. Lower `cache-min-ttl` if that matters.
