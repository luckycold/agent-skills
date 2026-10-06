# Upstream Docker Compose → TrueNAS Custom App

Pattern for projects that ship `docker-compose.production.yml` (or similar) and a prebuilt image — no clone/build on the NAS. Validated with FUTO Notes sync server (Jun 2026); reuse for any server+database compose stack.

## When to use

- Upstream README says: curl compose + `.env`, `docker compose up -d`
- One or more services with `depends_on` and healthchecks (e.g. app + Postgres)
- Luke wants it in **Apps** as `custom_app`, data under `/mnt/Apps/Applications/<name>/`, and exposed through the private app domain resolved from `~/.agents/private-context.md`

## Workflow (SSH on ${NAS_IP})

1. **Discover** — `curl` raw `docker-compose.production.yml` and `.env.*.example` from upstream (GitLab/GitHub raw URLs). Note required env vars and image registry.
2. **Pull image on NAS** — `docker pull <image:tag>` before registering (surfaces registry/auth issues early).
3. **Data dirs** — `mkdir -p /mnt/Apps/Applications/<name>/data/{blobs,postgres,...}` per compose volume layout.
4. **Secrets on NAS** — generate on the host, never in agent memory long-term:
   - DB password: `openssl rand -hex 32`
   - App admin password: random + hash via upstream’s documented one-shot, e.g.
     `docker run --rm <image> bun dist/index.js hash '<password>'` (FUTO Notes)
   - Write secrets into `user_config.yaml` `environment` lists via a **python** `yaml.dump` on NAS; avoid echoing hashes in chat logs when possible (deliver admin password to user once, suggest Proton Pass).
5. **Compose in ix-apps** — mirror **ninerouter** layout:
   - `user_config.yaml` with `services:` map, `version: "3.0"`
   - Duplicate identical content to `versions/1.0.0/templates/rendered/docker-compose.yaml`
   - `metadata.yaml` at app root, `app.yaml`, `README.md`
   - Multi-service blocks: copy `healthcheck` / `depends_on` from odysseus (e.g. `condition: service_healthy`)
6. **Register** — `midclt call app.metadata.generate` then `midclt call app.query` → `custom_app: true`, state often `STOPPED`.
7. **Start + recovery** — `midclt call app.start <name>`; poll until `RUNNING`. If state stays `STOPPED` and **no** `ix-<name>-*` containers exist:
   ```bash
   docker compose -f /mnt/.ix-apps/app_configs/<name>/versions/1.0.0/templates/rendered/docker-compose.yaml -p ix-<name> up -d
   midclt call app.start <name>
   ```
   Poll again; expect `DEPLOYING` → `RUNNING`.
8. **Traefik** — see `references/traefik-exposure-for-custom-apps.md`. Pick an unused host port (e.g. `ss -tuln`), bind `${NAS_IP}:<port>:<container>` for Traefik backend URL.
9. **Verify** — `docker ps`, `curl` LAN port, `curl -I https://<private-app-host>`, and app-specific login/API if documented.

## Port binding on this NAS

| Use case | Host bind |
|----------|-----------|
| Container-to-container only (bridge, internal API) | `127.0.0.1:<port>` |
| Traefik / LAN backend (odysseus, apprise, sync APIs) | `${NAS_IP}:<port>` or `0.0.0.0:<port>` per existing app |

Do not assume every service is `127.0.0.1` — match the consumer (Traefik hits NAS IP).

## FUTO Notes–specific notes (example)

- Image: `gitlab.futo.org:5050/futo-notes/futo-notes-server/server:stable`
- Env: `AUTH_MODE=password`, `FUTO_NOTES_PASSWORD_HASH`, `DATABASE_URL` with embedded Postgres password, `TRUST_PROXY=true` when behind Traefik
- App config: Settings → Sync → the private notes host from the private context + admin password
- Data backup: `/mnt/Apps/Applications/futo-notes/data/` (blobs + postgres)

## Proton Drive compatibility checks

Validated in October 2026 with the official Proton Drive CLI and the prebuilt [docker-proton-drive-backup](https://github.com/traktuner/docker-proton-drive-backup) image:

- Inspect architecture, CPU features, libc, dataset mount options, and available space before testing. TrueNAS can mount `/tmp` with `noexec`; `Permission denied` there does not establish binary incompatibility. Use an executable dataset for a temporary checksum-verified binary test, then remove the entire test directory.
- Test the upstream image without photo/source mounts, published ports, or an account login. A read-only root, tmpfs for `/data`, `/tmp`, and `/app/.next/cache`, dropped capabilities, and `no-new-privileges` worked. Verify both `proton-drive version` and the internal `/api/health` endpoint; remove the test container and newly pulled image afterward.
- The default `keychain` session backend requires a working Secret Service/D-Bus environment. The packaged app uses `PROTON_DRIVE_CREDENTIALS_STORE=unsafe_file`; this avoids a desktop keyring but stores session material in plaintext. Treat persistent `/data` as secret storage and assess storage-layer encryption. Verify actual permissions after login: use `0700` state directories and `0600` session files rather than assuming the binary enforces them. The official CLI also supports the separate GPG-backed `pass` password-store backend; it is not Proton Pass.
- Startup/health tests are not authenticated backup verification. After the user selects an option and signs in, use a dedicated disposable source/destination to test upload, unchanged-file handling, restore, deletion propagation, and session persistence across container recreation before scheduling a real mirror.
- This app's web UI has no built-in authentication. Protect the deployed route with the existing authentication proxy and mount sources read-only. Prefer TrueNAS-managed app deployment over adding host packages or custom sync glue.

Check the current [official CLI documentation](https://github.com/ProtonDriveApps/sdk/blob/main/cli/README.md) and upstream image configuration before reusing the procedure.

### Immich and Proton Photos scope

- The packaged backup app normalizes destinations to `/my-files`; a successful container smoke test does not prove support for the separate Proton Photos timeline. Check the [app adapter](https://github.com/traktuner/docker-proton-drive-backup/blob/main/src/server/cli.ts) before recommending it for Photos reconciliation.
- Reconcile by normalized original-content checksums and stable asset/node IDs, with owner and linked-media relationships retained. Proton's duplicate lookup uses both name and content, so it is insufficient for differently named copies. An incomplete scan, inaccessible asset, or remote-only photo is not proof of deletion. Protect unmanaged/shared items until their scope is explicitly resolved.
- Treat reported digest/size matches as candidates until verification. A live audit found negative Proton claimed sizes and known-digest size conflicts; flag these rather than silently normalizing them or inferring different content. Use server-reported storage sizes for quota estimates. Verify downloaded bytes and file counts in a canary: the tested CLI's batch download with rename reported two successful same-named downloads but left one local file. Separate per-node staging directories preserved both copies and verified their hashes and sizes.
- Before proposing remote cleanup, verify Immich's recorded original paths through the running container's actual mounts. Assets marked online can still have missing originals. Check existing ZFS snapshots for those exact relative paths, compare sizes, and verify content checksums before treating remote copies as redundant; snapshot availability alone is not a completed restore.
- Build the recovery file set from original-path and linked-media references, not directory names alone. Verified Live Photo video originals can reside inside `encoded-video`; excluding that entire directory as regenerable would omit those originals. Preserve sidecars, the database, and the path-to-remote-ID restore manifest as well.
- Immich `hidden` represents Live/Motion Photo video components; `locked` is a separate privacy state. In the reviewed Immich v3.2.4 source, locked searches require an elevated owner session and sync streams reject API keys. Never promise an ordinary read-only API key supplies a complete inventory or durable deletion/visibility feed. Treat unknown classification as excluded from new Photos uploads and unresolved for destructive cleanup.
- Check UID addressing separately for live and trashed Proton photos. The reviewed official CLI resolves live `/photos/<uid>` directly but looks up `/photos-trash/...` by name; duplicate names make unattended restoration ambiguous. Establish a supported UID-safe restore path before destructive reconciliation. Preserve an independent recoverable backup and review privacy policy before building custom integration.

## Upgrade

Change image tag in `user_config.yaml` + `templates/rendered/docker-compose.yaml`, `app.stop` / `app.start`, or `docker compose pull` on project `ix-<name>` then recreate via Apps UI.
