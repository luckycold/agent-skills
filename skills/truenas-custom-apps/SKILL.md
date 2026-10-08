---
name: truenas-custom-apps
author: Luke
category: devops
description: Class-level procedures for registering, updating, and managing custom Docker apps on TrueNAS SCALE as first-class entries in the Apps list. Covers the ix-apps/app_configs directory structure, midclt usage, direct YAML edits, and workarounds when app.create is restricted. Focuses on local-only services, data preservation under /mnt/Apps/Applications, and enabling integrations for self-hosted projects such as PewDiePie's Odysseus. Complements broader infrastructure-hygiene patterns.
---

# TrueNAS Custom App Management via CLI and ix-apps Structure

## Purpose and Scope
This skill captures the reliable class of work for adding or modifying custom apps (e.g. email bridges, web services) so they appear correctly in the TrueNAS UI as "Custom App" with full lifecycle support (start/stop/update, metadata, versioning).

Use when:
- `midclt call app.create` fails with validation errors or is restricted for custom apps.
- You need a service to be managed alongside existing custom apps like ninerouter and odysseus.
- The service provides local resources (IMAP, SMTP, etc.) for other containers/apps on the NAS, or must be deliberately exposed on standard client-facing ports with end-to-end verification.
- Maintaining consistency with Luke's TrueNAS setup conventions (least-necessary interface binding by default, explicit public exposure when requested, specific data paths, cleanup of legacy Dockge stacks).

## Prerequisites
- Configured SSH access to TrueNAS. Resolve `NAS_SSH_TARGET`, `NAS_SSH_KEY`, and `NAS_KNOWN_HOSTS` from `~/.agents/private-context.md` at runtime. Keep `BatchMode=yes`, isolate the selected identity when needed, and require strict host-key verification. If the host key is missing or changed, stop and verify it through a trusted channel; never fall back to an unverified host or `/dev/null` known-hosts file.
  ```bash
  ssh -o BatchMode=yes -o IdentityAgent=none \
    -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
    -i "$NAS_SSH_KEY" "$NAS_SSH_TARGET" 'midclt call app.query'
  ```
- At least one existing custom app (ninerouter or odysseus) to inspect and mirror.
- Python on the NAS for safe YAML load/dump during edits.
- Pre-created data directory and awareness of image-specific init flows (e.g. protonmail entrypoint).
- For credentialed services: Proton Pass agent ready with `PROTON_PASS_AGENT_REASON` usage and consent handling.

## High-Level Workflow
When the user requests execution (e.g. "I'm not at my computer right now. I want you to initialize... for me" or "can't you do all of this yourself?"), maximize autonomous actions via tools (SSH + docker + Pass agent) before falling back to commands. Execute dir prep, metadata generation, container start/stop/restart, Pass item views (with reason), TOTP generation, status polls, and extraction of visible relay creds. Only surface "complete the interactive password step with this TOTP" when raw secrets or real-time prompts are unavoidable.

1. Explore and mirror structure from a known-good custom app (ninerouter/odysseus recommended).
2. Prepare persistent data dir and clean legacy compose stacks (via SSH).
3. Create the full `/mnt/.ix-apps/app_configs/<name>/versions/1.0.0/` tree with the required files (or use the managed app update path).
4. Use `midclt call app.metadata.generate` to index the app.
5. Start via `midclt call app.start <name>` (or direct docker compose for the ix- project). If `app.query` stays `STOPPED` with zero containers, run `docker compose -f .../templates/rendered/docker-compose.yaml -p ix-<name> up -d` then `app.start` again (see `references/upstream-compose-multi-service-apps.md`). For credentialed services, run one-time init prep via `docker run --rm -i ...`.
6. For Proton Mail Bridge-style services (PTY login through `proton-pass-agent run`, TOTP handling, initial-sync lock, relay-credential capture), follow `references/proton-bridge-app.md`.
7. For updates to existing apps (catalog/community apps use the exact same user_config.yaml structure): backup + targeted edit of user_config.yaml in the versions dir (pay special attention to `network.dns_port.host_ips` and similar for published ports), then trigger update/stop+start. Note the frequent pitfall that port host_ip changes do not always take effect until a deeper redeploy or UI save — see the dedicated pitfalls subsection and `references/catalog-app-network-port-edits.md`.
8. When Luke wants HTTPS on his private app domain, resolve the exact domain and backend from `~/.agents/private-context.md`, then add `/mnt/Apps/Applications/traefik/dynamic/<name>.yml`. Skip `authelia` middleware for mobile/sync/API apps that authenticate with their own password or tokens; use Authelia for browser-only admin UIs (`references/traefik-exposure-for-custom-apps.md`). For Jellyfin specifically, where the browser should use Authelia OIDC but native apps must retain Jellyfin authentication, use the split-router design in `references/jellyfin-authelia-sso-native-clients.md`.

For upstream `docker-compose.production.yml` stacks (prebuilt image + Postgres, no repo clone on NAS), see `references/upstream-compose-multi-service-apps.md`. For projects whose best upstream artifact is a Home Assistant add-on image—including `/data/options.json`, bundled-Postgres bind permissions, safely aligning a Better Auth local login with an explicitly requested Authelia/LLDAP identity, connecting a manual-IMAP app to Proton Bridge without exposing relay credentials or sending a test message, and securely wiring the app's authenticated Streamable HTTP MCP endpoint into Hermes—see `references/home-assistant-addon-images-and-better-auth-identity.md`. For private-domain Traefik routes and when to skip Authelia for native API clients, see `references/traefik-exposure-for-custom-apps.md`.

## Key Directory and File Patterns
See `references/ix-apps-custom-app-structure.md` for the exact layout, file purposes, and condensed examples of metadata.yaml, app.yaml, user_config.yaml, rendered/docker-compose.yaml, and README.md.

Core conventions observed:
- Compose project prefix is always "ix-" (ix-ninerouter, ix-proton-bridge).
- Data volume target: `/mnt/Apps/Applications/<name>/data` mapped to the container's config path.
- Ports: `127.0.0.1:` for container-only consumers (IMAP/SMTP bridge); `${NAS_IP}:<port>` (or match an existing app) when Traefik or LAN hits the backend — see port table in `references/upstream-compose-multi-service-apps.md`.
- Active compose path on this stack is often `versions/1.0.0/templates/rendered/docker-compose.yaml` (keep in sync with `user_config.yaml`).
- Version is typically "1.0.0" for these manual custom apps.
- After file creation, `app.metadata.generate` + `app.query` confirms `custom_app: true`.

## Service-specific procedures

Load the matching reference before working on one of these apps:

- **FreshRSS:** for Folo reconciliation, YouTube/RSSHub feed conversion, podcast artwork, extensions and Extension Manager, PWA behind Authelia, entry-click and back-gesture extensions, and recovering a managed restart, see `references/freshrss-operations.md`. For the RSSHub Radar extension and stale `Retry-After` locks, see `references/freshrss-rsshub-radar-extensions.md`. Also `references/freshrss-card-gesture-layout.md`, `references/freshrss-touch-card-gestures.md`, and `references/freshrss-oled-theme-overlays.md`. Always back up PostgreSQL, the extensions tree, and config before changes. Never print RSSHub keys.
- **RomM multi-file folders:** publish atomically, normalize the whole tree's ownership, and verify file counts and bytes from inside the container. See `references/romm-multifile-folder-ingest.md`.
- **qbit_manage tracker retention:** see `references/qbit-manage-tracker-retention.md`. Never print announce URLs or passkeys.
- **Glance:** use the community catalog app with host paths, `run_as` 568:568, and seed the config before `app.create`. See `references/glance-catalog-app.md`.
- **proton-bridge:** see `references/proton-bridge-app.md` for the overview and pitfalls, plus `references/proton-bridge-pass-automation.md`, `references/proton-bridge-public-mail-client-exposure.md`, `references/proton-bridge-imap-health-libfido2.md` (with `scripts/probe-bridge-imap.sh`), and `references/proton-bridge-locked-vault-credential-recovery.md`. Never print relay credentials or TOTP material. A scan without a proven authenticated IMAP session is **incomplete**, never "no mail".
- **Upstream compose stacks (FUTO Notes, etc.):** see `references/upstream-compose-multi-service-apps.md`. The server image's UID (FUTO: 1000) must own its blob directory.
- **Jellyfin SSO plus native clients:** see `references/jellyfin-authelia-sso-native-clients.md`.

## Pitfalls and Anti-Patterns
- Never rely solely on `midclt call app.create` for custom apps on this system — it consistently hits validation blocks. Manual structure replication is the proven path.
- Legacy Dockge stacks at `/mnt/Apps/Applications/dockge/stacks/<name>` will conflict; remove them proactively.
- Start jobs are asynchronous — always poll `app.query` + `docker ps --filter name=<name>` and wait for "Up".
- **First `app.start` with no containers:** `app.query` may show `STOPPED` and `docker ps` shows no `ix-<name>-*` — run compose from `templates/rendered/docker-compose.yaml`, then `app.start` again until `RUNNING`.
- **Reusing a Home Assistant add-on image as a TrueNAS custom app:** mount `/data`, seed `options.json`, and keep the bind root traversable by internal service users (a `0770` root can break `initdb`). See `references/home-assistant-addon-images-and-better-auth-identity.md`.
- Data dir must exist with correct ownership **before** first start (and again after manual edits as root). Read `run_as.user` / `run_as.group` from the catalog `questions.yaml` or app metadata (Glance and most community apps default to **568:568**, user `apps`). For **host_path** storage under `/mnt/Apps/Applications/<app>/`, run `chown -R <uid>:<gid>` on every bind-mounted path **before** `app.create` / `app.start`. Catalog installs still run the `permissions` init container — verify with `ls -la` on the host path after deploy; files should be owned by `apps`, dirs `775`/`664` or similar, not `root:root`. If the app cannot write config or serves empty pages, fix ownership on the host path and `app.stop` then `app.start`. Custom images with non-568 UIDs (e.g. FUTO `1000:1000` on `blobs/`) must match the image user, not blindly 568.
- YAML edits: Always backup first; prefer python snippets over sed for complex service blocks.
- **TrueNAS catalog-app labels require container assignment:** each item in `values.labels` must include `containers: [<catalog container name>]` (for FreshRSS, `[fresh_rss]`). Adding only `key`/`value` makes `app.update` fail render with `Label [...] must have at least one container`. A failed update can still leave those invalid labels in `app.config`; immediately submit a corrected label set through `app.update`, then verify the app is RUNNING and the rendered container labels.
- Secrets/credentials: Use the pre-configured proton-pass-agent + explicit reason for every vault/item operation. Respect system blocks on secret viewing. Never embed real passwords in commands, logs, or memory. After obtaining bridge info, consider storing the *generated* bridge creds back into a new Pass item.
- Port binding: Omitting `127.0.0.1` on intentionally local-only services exposes them on all interfaces — use `127.0.0.1` by default. When public mail-client access is explicitly requested, bind only the required standard ports, document the exposure, and verify the complete chain rather than treating an all-interface Docker publish as internet reachability.
- **Proton Bridge pitfalls** (socat protocol mapping, probing in the configured TLS mode, DNS-only mail records, stale relay credentials, `socat` resets, sync-monitor timeouts, libfido2, empty data dir, keychain failures, TLS/DNS interception, historical vs current errors): see `references/proton-bridge-app.md`.
- Inspecting middlewared (crud.py, custom_app.py, ix_apps/*) is useful for understanding why manual registration works, but not required for routine additions.
- **Many apps STOPPED after a nightly auto-upgrade:** a failed image pull during `app.upgrade` leaves the app stopped on the new version. Diagnose with `core.get_jobs` and `app_lifecycle.log`, then recover with `app.start` once the registry is reachable. Start Authelia first, because protected routes return 500 while it is down. Then check the backup knock-ons: db-backup stuck on a stopped database host, and Backrest partial runs from files that uid 568 can't read. See `references/failed-auto-upgrade-and-backup-recovery.md`.
- **`midclt call app.restart <name>` does not exist** on this stack (`Method does not exist`). Restart custom apps with `app.stop` then `app.start`, then poll `app.query`.
- **Catalog/existing app port host-IP changes** (`network.*.host_ips`): back up `user_config.yaml` and edit it with python. A stop/start often does **not** move the published IP, so verify with `docker inspect` and `ss`. Confirm with Luke which IP clients should use as their DNS resolver before touching DHCP. See `references/catalog-app-network-port-edits.md`.

## Verification Checklist
- `midclt call app.query | jq '.[] | select(.name == "<name>") | {name, state, custom_app, version}'` → state=RUNNING, custom_app=true.
- `docker ps -a --filter name=<name>` shows container with correct port bindings.
- App visible in TrueNAS web UI under Apps.
- Data dir populated after init (`ls /mnt/Apps/Applications/<name>/data`).
- Local connectivity test from the intended consumer using the configured protocol mode.
- For public mail exposure: TLS hostname verification, authenticated IMAP/SMTP, DNS-only public record, WAN NAT/firewall, and probes from a genuinely external network all pass. Split DNS/hairpin success alone is insufficient.
- No old compose project conflicts.

## Related Skills and Overlaps
This skill focuses on the registration and structure mechanics for custom apps. It overlaps with the broader `infrastructure-hygiene` skill (Luke's TrueNAS/Home Assistant patterns). The background curator should consolidate if duplication grows. Also relevant for any self-hosted AI workspace setup (Odysseus) that needs supporting local services.

## How to Extend
- Add new references/ for specific images or common services.
- Capture new workarounds (e.g. new midclt behaviors after TrueNAS updates) via patch.
- When a user corrects the approach or a step fails in a repeatable way, patch this skill immediately.

Consult this skill before any new custom app work on the TrueNAS.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical package under `~/.agents/skills/` when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Make the smallest evidence-backed edit, never record credentials or secret values, and do not infer a durable preference from one request. Follow the `personal-skill-maintenance` skill for the full review and verification workflow.
