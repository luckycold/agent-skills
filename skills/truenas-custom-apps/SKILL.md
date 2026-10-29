---
name: truenas-custom-apps
author: Luke
category: devops
description: Register and update TrueNAS SCALE custom apps so they stay in the Apps UI. ix-apps layout, app.create pitfalls, Proton Bridge and its IMAP probe, immich-proton-sync bumps, and Traefik exposure including Jellyfin SSO.
---

# TrueNAS custom apps

Use this when a service has to appear as a Custom App with start, stop, and update in the TrueNAS UI. Broader lab rules (DNS, Authelia lockdown, qbit_manage orphans, RomM, ACME) are `infrastructure-hygiene`.

## Access

Resolve `NAS_SSH_TARGET`, `NAS_SSH_KEY`, and `NAS_KNOWN_HOSTS` from `~/.agents/private-context.md`. `BatchMode=yes`, the selected identity, and strict host-key checking. If the host key is missing or changed, stop. Do not use an unverified host or `/dev/null` as known hosts.

```bash
ssh -o BatchMode=yes -o IdentityAgent=none \
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
  -i "$NAS_SSH_KEY" "$NAS_SSH_TARGET" 'midclt call app.query'
```

Prefer, in order: a catalog app, a custom app through the Apps UI or `midclt call -j app.create` / `app.update`, then raw compose only when Luke asks. The app must stay visible in the UI. Data lives under `/mnt/Apps/Applications/<service>` as bind mounts. Keep Postgres and Redis private.

## Registration

`midclt call app.create` often fails validation for custom apps. Mirror a known-good app such as ninerouter: build `/mnt/.ix-apps/app_configs/<name>/versions/1.0.0/`, run `app.metadata.generate`, then `app.start`. Layout and file roles: [ix-apps structure](references/ix-apps-custom-app-structure.md).

If `app.query` stays `STOPPED` with zero containers, run `docker compose` from `templates/rendered/docker-compose.yaml` with project `ix-<name>`, then `app.start` again. See [upstream compose stacks](references/upstream-compose-multi-service-apps.md).

There is no `app.restart`. Use `app.stop` then `app.start`. `midclt call -j` is the job flag; `-job` is not valid.

## Traefik

For HTTPS on the private app domain, add `/mnt/Apps/Applications/traefik/dynamic/<name>.yml`. Skip `authelia` middleware for clients that authenticate themselves. Use Authelia for browser admin UIs. See [Traefik exposure](references/traefik-exposure-for-custom-apps.md). Jellyfin, where the browser uses Authelia OIDC and native apps keep Jellyfin auth: [Jellyfin SSO](references/jellyfin-authelia-sso-native-clients.md).

## Apps with their own procedure

- **proton-bridge:** [overview](references/proton-bridge-app.md), [Pass automation](references/proton-bridge-pass-automation.md), [public mail clients](references/proton-bridge-public-mail-client-exposure.md), [IMAP health and libfido2](references/proton-bridge-imap-health-libfido2.md) with `scripts/probe-bridge-imap.sh`, and [locked vault recovery](references/proton-bridge-locked-vault-credential-recovery.md). Never print relay credentials or TOTP. A scan without an authenticated IMAP session is incomplete.
- **immich-proton-sync** after an Immich update: the version guard leaves the app DEPLOYING until the allowlist is bumped. [Version bump](references/immich-proton-sync-version-bump.md). Proton Drive CLI quirks for that sync: [CLI verification](references/immich-proton-cli-verification.md).
- **ninerouter:** [maintenance](references/truenas-ninerouter-9router-maintenance.md).
- **FreshRSS:** [operations](references/freshrss-operations.md) and [RSSHub Radar](references/freshrss-rsshub-radar-extensions.md). Back up PostgreSQL, the extensions tree, and config. Never print RSSHub keys.
- **Glance:** [catalog app](references/glance-catalog-app.md).
- **Home Assistant add-on images** reused as custom apps, including Better Auth and Proton Bridge IMAP without exposing relay credentials: [add-on images](references/home-assistant-addon-images-and-better-auth-identity.md).
- **Catalog port `host_ips`:** a stop/start often does not move the published address. [Port edits](references/catalog-app-network-port-edits.md).
- **Nightly auto-upgrade leaves apps STOPPED:** [failed upgrade recovery](references/failed-auto-upgrade-and-backup-recovery.md).

qbit_manage orphans and RomM imports are in `infrastructure-hygiene`, not here.

Consistent database dumps for Backrest run from TrueNAS cron: `scripts/pg-dump-exec.sh` and `scripts/sqlite-dump.py`. The check procedure is `proxmox-homelab` backup health.

## Pitfalls

- Data directories must exist with the right owner before the first start. Read `run_as` from the catalog metadata. Glance and most community apps are **568:568** (`apps`). Custom image users (FUTO `1000:1000` on `blobs/`) must match the image, not 568.
- Catalog labels need `containers: [<name>]`. A label with only `key` and `value` fails render, and the bad labels can stick in `app.config` until a corrected `app.update`.
- Bind local-only services to `127.0.0.1`. An omitted address publishes on every interface.
- YAML edits: back up, then use Python rather than sed.
- `pool.snapshottask.create` rejects a `description` field. Use the fields the method accepts (`dataset`, `recursive`, `exclude`, `lifetime_value`, `lifetime_unit`, `naming_schema`, `schedule`, `enabled`, `allow_empty`).
- Secrets go through `proton-pass-cli` with `PROTON_PASS_AGENT_REASON`. Never embed passwords in commands, logs, or this skill.

## Checks

- `app.query` shows `RUNNING` and `custom_app: true`.
- `docker ps` shows the expected port bindings.
- The app is visible in the Apps UI.
- The data directory is populated after init.

## Self-maintenance

This is a Luke-authored personal skill. Update it when a verified correction would help the next run. Follow `personal-skill-maintenance`. Never record credentials.
