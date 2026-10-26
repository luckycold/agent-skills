# UniFi IoT VLAN: internet default-deny with an allowlist (legacy firewall API)

Use this to block internet access for new or unknown IoT devices while keeping trusted ones online (Google/Nest, vendor hubs that need firmware, Thread border routers, Home Assistant). Official controller API only: no gateway SSH, no scripts on the gateway. Back up `rest/firewallrule`, `rest/firewallgroup`, `rest/user`, and `rest/networkconf` before you change anything.

## Shape that works (legacy `rest/firewallrule`, posture ALLOW_ALL)
LAN_IN, after the existing IoT isolation rules (established/related, IoT→HA allow, IoT→"All Local" drop):
1. Allow IoT network → UDP 123 (any). Check `networkconf.dhcpd_ntp` first. If the gateway doesn't serve NTP, devices need NTP from the internet.
2. Allow address-group **"IoT internet allowlist"** → any.
3. Drop IoT network → any (the default deny).

- DNS and DHCP to the gateway's own IP go through LAN_LOCAL, not LAN_IN, so this doesn't affect them. Public DNS (8.8.8.8 and so on) is blocked for unlisted devices.
- Give each allowlisted device a fixed IP first (`rest/user` full-object PUT with `use_fixedip`, `fixed_ip`, `network_id`). Use its current lease so nothing renumbers.
- Main → IoT can stay open. Replies come back through established/related, and only IoT → main matters for isolation.

## IPv6 gotchas
- Check `networkconf.ipv6_subnets`. If the IoT VLAN is ULA-only there's no IPv6 internet and you need no IPv6 allowlist. Still add an IPv6 drop, because the global ALLOW_ALL otherwise lets IoT ULA reach the main ULA.
- LANv6_IN rules **reject a network source** (`api.err.FirewallRuleNetworkTypeInvalidForIpv6` with NETv4, `InvalidValue` with NETv6). Use an `ipv6-address-group` source instead, placed after the "IoT → HA IPv6" allow.
- With Thread on the IoT VLAN, put the IoT ULA /64, the OTBR on-link (AIL) prefix, and the Thread OMR prefix in that group. Traffic forwarded through a border router carries OMR source addresses, not the VLAN ULA.
- Never put a main-LAN prefix in that source group, because it's matched on every interface. Devices moved from main keep stale main GUA/ULA addresses until their valid lifetime ends (about 24h). Allowlist them if needed.
- Don't create an "IPv6 allowlist" placeholder containing the whole IoT /64. If someone wires it in later, it allows everything.

## Verify without touching devices
- An allowlisted host should `curl` a public HTTPS site successfully.
- For the blocked case: temporarily add an unused /32 from the IoT subnet to an allowlisted Linux host (`ip addr add`), then bind tests to it: `curl --interface`, and Python UDP sockets bound to that source for DNS-to-gateway, DNS-to-public, and NTP. Remove the address afterwards.
- Re-check casting (TCP 8009 from main, `_googlecast._tcp` with mDNS reflector `google_chromecast`), the Matter node count, and the monitors.

## Letting a user allow a new device (UniFi app)
Clients → the device → Settings → Fixed IP on → Save. Then Settings → Profiles → Port and IP Groups → "IoT internet allowlist" → add the IP → Save, and reconnect the device. Remove the IP to re-block it. For a one-off firmware update, add it temporarily.

## Rollback
Disable the default-deny rule(s) first (fastest). Then delete the allow rules and groups. Restore fixed IPs from the `rest/user` backup.
