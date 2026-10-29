# Home Assistant `.local` hostname conflict

Use this when `<ha-hostname>.local` does not resolve, but Home Assistant OS already has that hostname.

## Cause

systemd-resolved treats a reflected mDNS answer as a foreign claim and renames the published hostname (`homeassistant` to `homeassistant8`, then upward). A second NIC on another VLAN plus a gateway mDNS reflector is enough. The conflicting address is often the host's own address. The OS hostname stays correct while `.local` never settles.

Do not add a unicast record for `.local`. Do not rename the host to escape the counter.

## Check

From the HA SSH add-on:

```bash
ha host info
ha network info
ha host logs -t systemd-resolved -n 30 -v
```

A loop of `Hostname conflict, changing published hostname` is the signature. From another LAN host, `avahi-browse` showing only a UUID `.local` name, or a rapidly changing `homeassistantN.local`, confirms the publisher is not stable.

## Fix

Leave the primary interface on `announce`. Set the non-primary interface to resolve-only so the reflector stops bouncing a second copy of the name:

```bash
ha network update <secondary-interface> --mdns resolve --llmnr resolve
```

Confirm the journal stops after `System hostname changed to '<ha-hostname>'` and that `avahi-resolve -n <ha-hostname>.local` returns the host address. Do not reboot unless that line never appears.

## Client lookup

`avahi-resolve` succeeding while `getaddrinfo` fails means the client is not using mDNS. On Arch, install `nss-mdns` when `nsswitch.conf` already lists `mdns_minimal`. If systemd-resolved is the only resolver, its global and per-link MulticastDNS settings must both be enabled. `mdns_minimal [NOTFOUND=return]` will not fall through to unicast DNS.
