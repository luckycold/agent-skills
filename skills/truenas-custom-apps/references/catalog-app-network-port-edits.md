# Catalog app host_ips changes

Editing `network.*.host_ips` in a catalog app's `user_config.yaml` and then `app.stop` / `app.start` often leaves the old Docker publish in place. Confirm with `docker inspect` (`NetworkSettings.Ports`) and `ss`. A deeper `app.update`, upgrade, or UI save is what actually moves the address.

Back up `user_config.yaml` and edit it with Python. Every catalog label still needs `containers: [<name>]`.

## DNS is not this publish

The router is the resolver DHCP should hand out. AdGuard is opt-in for devices Luke names. Do not set UniFi `dhcpd_dns_1` to a NAS address, do not add `1.1.1.1` as a secondary, and do not DNAT port 53 on the NAS to pretend an alias is lab DNS.

`${NAS_IP}` is the TrueNAS UI. `${REVERSE_PROXY_IP}` is Traefik. Those are not the DNS listener. Before changing a publish, say which address clients should query and which address a name should resolve to. They are different.

Lab DNS recovery is `infrastructure-hygiene` [lan-dns.md](../../infrastructure-hygiene/references/lan-dns.md).
