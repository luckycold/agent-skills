# TrueNAS app deployment preference and conventions

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

When deploying apps on Luke's TrueNAS SCALE host, prefer approaches in this order:

See `references/truenas-custom-app-cli-registration.md` for the complete manual registration + Dockge-to-Custom-App migration procedure (including the exact `/mnt/.ix-apps/app_configs/<name>/` structure, python calls to `setup_install_app_dir`/`update_app_config`/`update_app_metadata`/`compose_action`, ix- prefix handling, and the proton-bridge case that drove the pattern). Use this when `midclt app.create` is restricted.

1. Official/native TrueNAS Apps from the catalog.
2. Custom TrueNAS Apps created through the TrueNAS Apps UI.
3. Custom app YAML / Docker Compose only when the first two do not fit.

Deployments should remain visible/manageable through the TrueNAS UI whenever possible. Avoid standalone compose projects that TrueNAS cannot see unless Luke explicitly asks for that style.

For SCALE custom Compose apps, create/update through middleware instead of manual `docker compose` so the app appears in the UI:

```bash
# create
midclt call -j app.create '{"app_name":"<name>","custom_app":true,"custom_compose_config_string":"<compose-yaml-string>"}'

# update existing custom compose
midclt call -j app.update <name> '{"custom_compose_config_string":"<compose-yaml-string>"}'
```

Use project name `ix-<app>` if an updater container must rebuild via the Docker socket, e.g. `docker compose -p ix-<app> -f /compose/docker-compose.yml up -d --build <service>`, so it updates the TrueNAS-managed Compose project rather than creating a standalone one.

For custom or self-hosted multi-container services on TrueNAS SCALE:

- Target the dedicated Apps pool at `/mnt/Apps/Applications/<service>` for app files and persistent data unless the TrueNAS app's UI-generated storage paths dictate otherwise.
- Use bind mounts on ZFS datasets/directories instead of Docker named volumes where possible. This ensures native TrueNAS storage management, snapshots, and permissions.
- Expose only the necessary app ports; keep internal services such as Postgres and Redis private to the app network or bound to localhost when possible.
- A supported exposure pattern is Traefik as a TrueNAS app bound to `${REVERSE_PROXY_IP}:80/443`, Docker provider with `exposedByDefault=false`, an external proxy network, app-level labels, and narrowly scoped dynamic configuration files.
- Use `authelia@file` / Authelia forwardAuth for private routes unless an app intentionally handles public auth itself; Authelia is backed by LLDAP. Cloudflared provides tunnel ingress without publishing app ports directly.
- Fix common container permission issues immediately (e.g. mounted entrypoint/init scripts must be readable/executable by the container user).
- Ensure passwords in app environment blocks exactly match connection URIs used by dependent services.
- TrueNAS `pool.snapshottask.create` rejects a `description` field; use only accepted fields such as `dataset`, `recursive`, `exclude`, `lifetime_value`, `lifetime_unit`, `naming_schema`, `schedule`, `enabled`, and `allow_empty`.

This is the preferred native/manageable pattern the user expects for TrueNAS infrastructure.
