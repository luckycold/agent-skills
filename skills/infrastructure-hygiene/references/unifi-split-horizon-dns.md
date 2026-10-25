# UniFi split-horizon DNS: forward domains, wildcard records, and Cloudflare AAAA/ECH

Applies when the UniFi gateway answers a public, Cloudflare-proxied zone locally (wildcard A to a LAN reverse proxy).
Make changes only through the UniFi Network app or its API; never SSH into the gateway to edit dnsmasq (warranty rule).

## What UniFi actually does
- **A wildcard A record (`*.example.com`) answers A only.** AAAA, HTTPS/SVCB, TXT and so on still go to the upstream resolver, so public
  Cloudflare AAAA and HTTPS records (ipv6hint, `ech=`) reach LAN clients. To test, add a throwaway wildcard on a name whose public
  AAAA is predictable (e.g. `*.test.sslip.io` with labels like `2606-4700--1`), query AAAA, then delete it. Records take about 20-30 s to apply.
- **An NS record in the DNS records list is a Forward Domain** (all queries for that domain go to the given server, except A
  queries the local records already answer). If that server's own host sends a query, the gateway won't forward it back to the
  sender (loop guard), has no other server, and answers **REFUSED**. Typical symptom: one host (often the box that used
  to run the old resolver) gets REFUSED for AAAA while every other client gets NOERROR. Check with `dig -b <each source IP>`.
- Forwarding non-A types to an old resolver can also break records silently: a resolver rewrite for `*.zone` can blank out
  SRV/TXT for names under it.
- **Device "Local DNS record" entries** (Client settings, API `rest/user` `local_dns_record`) are separate from the DNS
  records list. They answer authoritatively, and the API refuses a static record with the same name (`StaticDnsOverlapsWithDeviceLocalDns`).
  Check them before assuming a name depends on a forward.

## Removing a forward to a retired resolver without leaking public addresses
1. Back up the static-dns list (`GET /proxy/network/v2/api/site/default/static-dns`) and the device local DNS entries.
2. In Cloudflare for the zone: turn **ECH off** first. An ECH-capable browser that gets the HTTPS record would send its
   ClientHello with Cloudflare's outer SNI to the LAN proxy, and TLS fails. Then turn **IPv6 Compatibility off**. Both are zone settings
   (`PATCH /zones/{id}/settings/ech|ipv6 {"value":"off"}`). On the Free plan the API reported them editable and the change
   worked, even though the docs table says only Enterprise can customize IPv6. Check the authoritative NS (`dig @<zone NS>`):
   no AAAA, HTTPS record without `ech`/`ipv6hint`. Then wait the 300 s proxied TTL.
3. Delete the more specific forward first, check, then the zone forward. Checks (from several hosts, including the old
   resolver's host): local A unchanged, AAAA NOERROR/empty, TXT/MX/SRV public, HTTPS without `ech`, LAN routes load through the
   proxy, a public route works through Cloudflare over IPv4, and a capture on the old resolver shows zero queries from the gateway.
4. Rollback: re-POST the saved NS records; PATCH the Cloudflare settings back to `on`.
Cost: public visitors reach the zone over IPv4 only (IPv6-only mobile networks still work via NAT64/464XLAT) and lose ECH.
Don't invent AAAA records: a wildcard AAAA to a ULA is the fallback, and it needs the proxy to listen on IPv6 and the LAN-bypass rules to include the ULA.
