---
name: ntfy-ops
description: Operate Luke's self-hosted ntfy push-notification server (TrueNAS catalog app behind Traefik) — locate it, health-check it, audit auth/access control, know which services publish to it, and wire new publishers such as Proxmox VE notification targets or cron watchdogs.
author: Luke
category: devops
---

# ntfy Operations

Luke runs his own ntfy server for phone push notifications. Resolve the real hostname, NAS address, host port, topic names, and credential item names from `~/.agents/private-context.md` (section **ntfy**). This skill keeps placeholders only: `${NTFY_URL}` (public base URL), `${NAS_IP}`, `${REVERSE_PROXY_IP}`, `<ntfy-port>`, `<topic>`.

Related skills: `truenas-custom-apps` / `infrastructure-hygiene` (TrueNAS app and Traefik conventions), `proxmox-homelab` (PVE notifications), `proton-pass-cli` (tokens).

## Where it runs

- It's a TrueNAS **catalog** app named `ntfy`, with container `ix-ntfy-ntfy-1`. Manage it through `midclt call app.*` and the TrueNAS UI, not standalone compose.
- It listens on `<ntfy-port>` on the NAS and is exposed by Traefik **Docker labels** on the app (`Host(<ntfy-host>)`, `websecure`). Clients resolve the hostname to `${REVERSE_PROXY_IP}` through home DNS.
- Configuration is through `NTFY_*` environment variables in the app config. Mounts: an app config dir → `/etc/ntfy`, and the ix app_mounts data dir → `/var/ntfy` (`cache.db`, `attachments/`).

## Health check (read-only)

```bash
curl -fsS "${NTFY_URL}/v1/health"                                     # {"healthy":true}
curl -fsS --resolve <ntfy-host>:443:${REVERSE_PROXY_IP} "https://<ntfy-host>/v1/health"   # Traefik path
ssh root@${NAS_IP} "midclt call app.query '[[\"name\",\"=\",\"ntfy\"]]' '{\"select\":[\"name\",\"state\",\"human_version\"]}'"
ssh root@${NAS_IP} 'docker ps --filter name=ix-ntfy --format "{{.Names}} {{.Status}} {{.Ports}}"'
```

## Auth / access-control audit

ntfy enforces users and ACLs only when `auth-file` is configured (`NTFY_AUTH_FILE` env or `auth-file:` in `server.yml`). `auth-default-access` controls anonymous access.

```bash
ssh root@${NAS_IP} 'docker inspect ix-ntfy-ntfy-1 --format "{{range .Config.Env}}{{println .}}{{end}}" | grep ^NTFY_ | sed -E "s/=.*//"'
ssh root@${NAS_IP} 'docker exec ix-ntfy-ntfy-1 sh -c "ls -la /etc/ntfy; grep -E \"^(auth|base-url|behind-proxy)\" /etc/ntfy/server.yml 2>/dev/null"'
```

- A `user.db` in `/etc/ntfy` without `NTFY_AUTH_FILE` means the user database exists but is **not enforced**: topics are open to anyone who can reach the URL. Observed 2026-10; re-verify before relying on it.
- Before enabling auth, inventory every publisher and subscriber below. Each one then needs a token or user, or it will break. Store tokens in Proton Pass and inject them at runtime; never put them in skills, compose text, or chat.
- Check whether the hostname is also reachable from outside (Cloudflare/Tailscale) before calling the server LAN-only.

## Known publishers (verify live)

- FreshRSS webhook notifications. Luke's preference: show only the feed name and an article preview on one line, no category label (`{feed_name}`, not `{notify_source}`). A dedicated Traefik dynamic file handles a mark-read callback.
- The Immich watchdog script (NAS root cron) notifies on state changes with a cooldown.
- Apprise (TrueNAS app) can fan out to ntfy.
- Agent cron jobs that are "silent unless signal" should notify through ntfy only on real findings.

When adding a publisher, record its topic and credential *names* in private context.

## Publishing

```bash
curl -fsS -H "Title: <title>" -H "Priority: default" -H "Tags: warning" \
  -d "<message>" "${NTFY_URL}/<topic>"
# with auth: add -H "Authorization: Bearer $NTFY_TOKEN" (token injected from Pass, never echoed)
```

## Wiring a Proxmox VE notification target (on approval)

PVE 8.1+ has a native notification system. Prefer the **webhook** target over scripts:

1. Datacenter → Notifications → Add → Webhook (or `/etc/pve/notifications.cfg` via `pvesh create /cluster/notifications/endpoints/webhook`).
   - Method `POST`, URL `${NTFY_URL}/<topic>`.
   - Headers: `Title: {{ title }}`, `Priority: {{#if (eq severity "error")}}high{{else}}default{{/if}}` (keep it simple if templating fails), and an `Authorization` header from a PVE **secret** field if auth is enabled.
   - Body: `{{ message }}`.
2. Add the target to a matcher (for example `severity error,warning`), or to the existing default matcher alongside email.
3. Test with the **Test** button (`pvesh create /cluster/notifications/targets/<name>/test`) and confirm the phone receives it.
4. PBS 3.1+/4.x has the same webhook target type. Wire it so prune, GC, and sync failures reach ntfy too.

Do not remove the existing email targets unless Luke asks.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update this package when a verified reusable correction or repeatable workflow would improve future runs. Keep hostnames, topics, and credential item names in `~/.agents/private-context.md`, never here. Follow `personal-skill-maintenance` for review, the public-safety check, and publishing.
