# Moving lab DNS clients to a different LAN resolver (e.g. AdGuard -> router)

1. **Compare first.** `dig +short @<new> <name>` vs `@<old>` for every proxied route name, wildcard probes (`random.<domain>`), split-horizon names, short host names, and a few external names. Stop and report any internal name the new resolver answers with public/CDN IPs; the owner decides between adding a local record and accepting the public path.
2. **Check the new resolver doesn't depend on the old one** (tcpdump on the old resolver host for `src host <new> and dst port 53` while probing). Burst-test it (a few hundred parallel queries) for rate limits.
3. **Inventory clients** from the old resolver's query log (per-client counts and top names, last 24 h) plus configs: TrueNAS `midclt call network.configuration.config`, Proxmox nodes (`/etc/resolv.conf`, `tailscale dns status` system resolver), `pct exec <ct> -- cat /etc/resolv.conf`, `qm guest exec <vm> -- resolvectl dns`, explicit `dns:` in compose files. Clients behind router NAT show up as the router IP.
4. **Repoint** with a backup of each config:
   - TrueNAS: `midclt call network.configuration.update '{"nameserver1":"<new>","nameserver2":"","nameserver3":""}'`. No public secondary: public resolvers answer internal names with CDN IPs (that broke a tunnel origin once). The change rewrites the host resolv.conf only; no app restarts.
   - Docker containers keep the upstreams captured at start (`# ExtServers: [host(...)]` in the container's `/etc/resolv.conf`) until each app restarts/updates. List them with `docker exec <c> cat /etc/resolv.conf`; distroless images need `docker cp <c>:/etc/resolv.conf -`. Restart only the ones that matter; auto-updates pick up the rest.
   - TrueNAS app restart: `midclt call -j app.redeploy <app>` (there is no `app.restart`).
5. **Monitoring:** replace old-resolver checks with checks against the new resolver; pause (don't delete) the old ones.
6. **Re-verify** after ~10 min in the old resolver's query log: repointed hosts should be gone except for un-restarted containers.
