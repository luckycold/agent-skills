# UniFi DHCP DNS and controller API

The router is DNS (2026-10-29). LAN DHCP hands out the gateway, not AdGuard and not a public resolver. AdGuard is opt-in for devices Luke names. Local names are UniFi records. `${NAS_IP}` is the TrueNAS UI. `${REVERSE_PROXY_IP}` is Traefik. Neither is the DNS listener.

Phones that resolve internal names only on VPN are usually getting a DHCP DNS server or search domain that does not match the router. Resolve private domain names from `~/.agents/private-context.md`.

## Checks

```bash
dig +time=3 +tries=1 +short @${GATEWAY_IP} "$PRIVATE_SEARCH_HOST" A
dig +time=3 +tries=1 +short @${GATEWAY_IP} "$PRIVATE_SEARCH_HOST" AAAA
# Traefik route, separate from which server answered DNS:
curl -kI --resolve "$PRIVATE_SEARCH_HOST:443:${REVERSE_PROXY_IP}" "https://$PRIVATE_SEARCH_HOST/"
```

## Fixing the Router (UniFi Controller REST API)
No SSH to the router (connection refused on 22). Use the controller API directly.

### API-key path (preferred when saved)
1. Resolve the scoped wrapper, vault, and item names from `~/.agents/private-context.md`, then locate the API key with a short REASON (viewer role is sufficient for read):
   ```bash
   export PROTON_PASS_AGENT_REASON="Locate UniFi API key for DHCP DNS fix"
   "$PROTON_PASS_AGENT" item list "$PROTON_PASS_VAULT" --output json
   ```

2. One-shot mutation (export the key in the current shell only; redact everywhere):
   ```bash
   export KEY="[REDACTED]"
   curl -s -k -H "X-API-Key: $KEY" \
     "https://${GATEWAY_IP}/proxy/network/api/s/default/rest/networkconf" \
     | python3 -c '...'   # parse and print the Default network object
   ```

3. Re-verify the network object after the PUT.

### SSO/MFA fallback path (worked July 2026)
If no UniFi API key is saved, resolve the approved controller-login item from the private context and use it only in memory; never print password, TOTP, cookies, or CSRF tokens.

- `POST https://${GATEWAY_IP}/api/auth/login` with JSON `{username,password,rememberMe:false,token:<totp>}` returns a `TOKEN` cookie and CSRF headers.
- UniFi writes require the CSRF header **exactly as `X-Csrf-Token`** (case observed in headers); carrying no/empty token returns `403 Forbidden` even if reads work.
- DHCP config read endpoint: `/proxy/network/api/s/default/rest/networkconf`.
- Local DNS records endpoint: `/proxy/network/v2/api/site/default/static-dns`.
- Exact A record create shape that worked:
  ```json
  {"enabled":true,"key":"<private-search-host>","record_type":"A","value":"<target-ip>","ttl":0,"port":0,"priority":0,"weight":0}
  ```
- After creating a record, poll DNS until propagation:
  ```bash
  dig +time=3 +tries=1 +short @${GATEWAY_IP} "$PRIVATE_SEARCH_HOST" A
  ```

## Read-only VLAN and IoT firewall audit

Use the authenticated controller session above; keep credentials, MFA values, and cookies in memory and log out when finished. A request to assess isolation does not authorize changing the network.

1. GET `/proxy/network/api/s/default/rest/networkconf` and `/proxy/network/api/s/default/rest/wlanconf`. Resolve Wi-Fi `networkconf_id` values to networks; report `vlan_enabled`, `vlan`, `network_isolation_enabled`, `internet_access_enabled`, and Wi-Fi `l2_isolation`. A guest-named SSID can still use the main LAN, and separate VLANs alone do not prove firewall isolation.
2. GET `/proxy/network/api/s/default/rest/firewallrule` and `/proxy/network/api/s/default/rest/firewallgroup`. Resolve source/destination group and network IDs, sort each ruleset by `rule_index`, and inspect enabled rules in order. Disabled drop rules provide no protection, and an earlier broad accept can prevent a later drop from matching.
3. Check connection-state flags rather than rule names. A manual accept rule with `state_new`, `state_invalid`, `state_established`, and `state_related` all true also accepts new and invalid traffic. Established/related describes connection tracking, not whether an application's traffic is useful or necessary.
4. Inspect IPv4 and IPv6 independently. Verify the actual ruleset and address-group family, and distinguish IPv6 ULA ranges from global prefixes; rule names mentioning IPv6 are insufficient evidence of IPv6 enforcement.
5. Check additional policy surfaces supported by the installed version: `/proxy/network/v2/api/site/default/trafficrules`, `/proxy/network/v2/api/site/default/firewall-policies`, `/proxy/network/v2/api/site/default/firewall/zone`, and `/proxy/network/v2/api/site/default/acl-rules`. An unsupported endpoint or 404 is not proof that its feature is absent.
6. Optionally GET `/proxy/network/api/s/default/stat/sta` to confirm that clients actually occupy the networks. Summarize counts by network ID or subnet without printing client identifiers or names. Report separately whether VLANs exist, inter-VLAN traffic is blocked, peers are isolated, and IoT internet access is restricted. State whether the finding comes from configuration inspection or an end-to-end traffic test.

See Ubiquiti's [network/client isolation guide](https://help.ui.com/hc/en-us/articles/18965560820247-Implementing-Network-and-Client-Isolation-in-UniFi) and [firewall connection-state documentation](https://help.ui.com/hc/en-us/articles/27699646208279-UniFi-Gateway-Advanced-Firewall-Rules) for the distinct control layers.

## Applying IoT isolation while preserving Home Assistant

1. Establish a live baseline before writes: integration-entry load states, entity availability, device/entity registries, recent error metadata, and active network interfaces/routes. Inspect physical interfaces as well as HA's selected discovery interface; HA can have direct connections to multiple VLANs. Record actual listener ports and media callback paths instead of assuming the default HA port. Keep backups owner-only and omit camera access tokens, entity context, and other credential-bearing attributes.
2. Verify working devices without actuating them. For Matter, use the installed `MatterClient`, wait for its listening-ready event, and make bounded `read_attribute(node_id, '0/40/3')` calls on available nodes. An available flag alone does not prove a fresh protocol exchange. Check Cast and camera listeners separately. Existing unavailable devices and unloaded integrations belong to the baseline, not to the change's regression count.
3. Back up complete firewall/network objects and journal each mutation. Preserve internet access, DHCP/DNS, and required multicast discovery; apply narrow HA exceptions before blocking unrelated local networks. Include the relevant addresses of every HA interface and check both request and callback directions. Do not assume a same-VLAN HA-to-device connection bypasses gateway policy. Apply Wi-Fi client isolation as a separate stage after routed isolation passes.
4. Validate the installed controller's legacy schema before enabling blocks. IPv6 uses `LANv6_IN`, not an IPv6-named `LAN_IN` rule. On the tested controller, IPv4 indices started at `20000` and IPv6 at `25000`. The network-type enum accepted `NETv4`, but populated IPv4 network selectors were rejected for IPv6 rules; IPv6 address groups with empty network selectors worked. Do not extrapolate these index ranges or schemas to another version without validation.
5. Test from a real IoT-side host, using an existing VM guest agent when direct SSH is unavailable. Confirm unrelated local services fail, HA exceptions succeed, and DNS plus public internet still work. Test IPv6 separately against a known live target, with a trusted-LAN positive control. Any temporary test address/route must be removed in a `finally` cleanup. Repeat fresh Matter reads and compare HA availability with the baseline; allow reconnection time and investigate persistent regressions before proceeding.
6. If rolling back, delete newly created rules before restoring original rule indices; otherwise index collisions can prevent restoration. Verify the final persisted configuration and repeat the affected traffic tests. Keep rollback material private and report the scope actually tested.

## Post-Fix Client Action
Router/DNS changes are instantaneous for new lookups, but existing clients may retain old DHCP options/cache until renewal:
- Forget the WiFi network + rejoin (most reliable), or reboot / toggle airplane mode.
- Flush browser/OS DNS cache where possible.
- If LAN split DNS matters, avoid public DNS as a DHCP secondary unless you accept occasional NXDOMAIN/leakage from clients that race/select the public server.

Clients should receive the router as primary DNS, with no public secondary. A public secondary produces NXDOMAIN or Cloudflare answers when a client selects it. Split-horizon record shape is [unifi-split-horizon-dns.md](unifi-split-horizon-dns.md). TrueNAS and Docker resolver recovery is [lan-dns.md](lan-dns.md).

## Search domain

If a private search-domain FQDN fails while an older name still works:

1. Read the DHCP `domain_name` and DNS addresses from `networkconf`.
2. Confirm the missing name exists as a UniFi static or device-local record, not only under a retired namespace.
3. Renew client leases after the change. Forget the Wi-Fi network and rejoin when the phone keeps the old options.

Do not mask the device zone with a wildcard that hides UniFi hostnames. An app wildcard belongs on the app zone and still has to pass the AAAA/HTTPS checks in the split-horizon note.

## Cross references

- `proton-pass-cli` for viewer role, reason length, and redaction when reading the UniFi API key.
