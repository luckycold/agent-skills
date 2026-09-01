# Catalog App Network/Port Host IP Edits + Bridge Workarounds

Concrete pattern from AdGuard Home on a dual-IP TrueNAS host. Resolve exact addresses and the private test hostname from `~/.agents/private-context.md`. The goal is to make the alias the client-visible DNS server that DHCP distributes while preserving the internal service rewrite.

## Key Files
- `/mnt/.ix-apps/app_configs/adguard-home/versions/1.3.12/user_config.yaml` (or latest version dir)
- The `network` block controls published ports for catalog apps.

## Edit Pattern
```yaml
network:
  dns_port:
    bind_mode: "published"
    host_ips:
    - "${REVERSE_PROXY_IP}"     # target client-facing resolver IP here
    port_number: 53
  # web_port and other services often stay on the primary or are handled by Traefik labels
  host_network: false
```

Always:
1. `cp user_config.yaml user_config.yaml.bak.$(date +%s)`
2. Use python:
   ```python
   import yaml
   with open(...) as f: data = yaml.safe_load(f)
   data["network"]["dns_port"]["host_ips"] = ["${REVERSE_PROXY_IP}"]
   with open(...) as f: yaml.dump(data, f, default_flow_style=False, sort_keys=False)
   ```

## Redeploy Gotcha (the main pitfall)
- `midclt call app.stop adguard-home && sleep 10 && midclt call app.start adguard-home`
- Frequently the running container **keeps the old publish** (`docker ps` and `docker inspect ... Ports` still show `${NAS_IP}:53->53`).
- `ss -tuln | grep :53` confirms only the old IP is listening from the host.
- The ix-apps runtime appears to treat port host_ip changes as requiring a deeper update/upgrade cycle (or UI-triggered redeploy) rather than a simple stop/start.

## Immediate Bridge (when user goal is "${REVERSE_PROXY_IP} must be the DNS server now")
Use host iptables DNAT so queries to the alias are forwarded to the current real listener. This makes .0.2 act as the resolver without waiting for the app.

```bash
# PREROUTING for inbound client traffic
iptables -t nat -A PREROUTING -d ${REVERSE_PROXY_IP} -p udp --dport 53 -j DNAT --to-destination ${NAS_IP}:53
iptables -t nat -A PREROUTING -d ${REVERSE_PROXY_IP} -p tcp --dport 53 -j DNAT --to-destination ${NAS_IP}:53

# OUTPUT for tests originating on the NAS itself
iptables -t nat -A OUTPUT -d ${REVERSE_PROXY_IP} -p udp --dport 53 -j DNAT --to-destination ${NAS_IP}:53
iptables -t nat -A OUTPUT -d ${REVERSE_PROXY_IP} -p tcp --dport 53 -j DNAT --to-destination ${NAS_IP}:53
```

Verification:
- `nslookup "$PRIVATE_TEST_HOST" "$CLIENT_DNS_IP"` should return the intended private rewrite target.
- `ss -tuln | grep ${REVERSE_PROXY_IP}:53` will still show nothing (the forward is at nat level)
- `docker inspect ix-adguard-home-adguard-1 --format '{{json .NetworkSettings.Ports}}' | grep 53`

## Persistence
```bash
cat > /root/apply-dns-forward.sh << 'EOP'
#!/bin/bash
# idempotent
iptables -t nat -C PREROUTING -d ${REVERSE_PROXY_IP} -p udp --dport 53 -j DNAT --to-destination ${NAS_IP}:53 2>/dev/null || \
  iptables -t nat -A PREROUTING -d ${REVERSE_PROXY_IP} -p udp --dport 53 -j DNAT --to-destination ${NAS_IP}:53
# (repeat for tcp + both OUTPUT rules)
echo "DNS forward for ${REVERSE_PROXY_IP}:53 applied $(date)"
EOP
chmod +x /root/apply-dns-forward.sh

# crude but reliable on TrueNAS
echo "@reboot root /root/apply-dns-forward.sh" >> /etc/crontab
```

(Alternative: put the script in a TrueNAS Post Init Script via the UI for better visibility.)

## Cleanup Later
Once the catalog app is updated/redeployed and `docker inspect` shows the publish has moved to ${REVERSE_PROXY_IP}:53 natively, the iptables rules (and cron) can be removed. The earlier user_config edit will then be sufficient.

## Related UniFi Side (for completeness)
After the TrueNAS side is ready, flip the LAN "Default" network via UniFi API:
- PUT to `/proxy/network/api/s/default/rest/networkconf/<network _id>`
- Set `dhcpd_dns_1: "${REVERSE_PROXY_IP}"`, `dhcpd_dns_2: "1.1.1.1"`
- Force clients to renew (forget WiFi + rejoin is most reliable).

This pattern appears when a dual-IP host (primary for one role, alias for services) + catalog app port pinning + desire for a particular IP to be the "DNS server" clients actually talk to.

## Session Context (2026-06)
- App: adguard-home (v0.107.77 container)
- Host IPs: ${NAS_IP} (primary, originally published) + ${REVERSE_PROXY_IP} (alias, desired resolver + service target)
- Inside container bind_hosts was already 0.0.0.0; the limitation was the Docker publish in the generated compose.
- User explicit correction: "make the DNS server ${REVERSE_PROXY_IP} then ... when I do a DNS lookup it uses .0.2 so that Seer can be seen".

Update this reference whenever a similar catalog app port migration or dual-IP resolver requirement appears.