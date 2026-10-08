# Recovering apps left STOPPED by a failed auto-upgrade, and the backup chain behind them

Verified 2026-10-08 on TrueNAS 25.10. Resolve hosts, ports, and app names from `~/.agents/private-context.md`.

## Failure signature

- Several apps are `STOPPED` at once, and nobody stopped them on purpose.
- `core.get_jobs` shows `app.upgrade` jobs that `FAILED` within a few minutes of each other at the auto-updater's cron time, each paired with a successful `app.stop`:
  ```bash
  midclt call core.get_jobs '[["method","=","app.upgrade"]]' '{"order_by":["-id"],"limit":20}' \
    | jq -c '.[] | {id, arguments, state, t: (.time_started["$date"]/1000|todate), err: (.error|tostring|.[0:120])}'
  ```
- `/var/log/app_lifecycle.log` has `Failed 'up' action` with `registry-1.docker.io ... context deadline exceeded`, or a DNS lookup error. That means the image pull failed, not that the app is broken.
- An auto-updater container (for example `marvinvr/truenas-auto-update` with `ONLY_UPDATE_STARTED_APPS=true`) logs `Failed to upgrade <app>`, one line per app. Its Apprise alert can fail during the same outage, so nobody is notified.

`app.upgrade` stops the app and switches the metadata to the new version **before** it pulls images. When the pull fails, the app stays STOPPED on the new version, and `upgrade_available` reads `false`.

## Safe recovery

1. Confirm the registry is reachable again: `curl -sS -o /dev/null -w '%{http_code}' https://registry-1.docker.io/v2/` should return `401`.
2. For each app, compare the images in the last two `versions/*/templates/rendered/docker-compose.yaml`. A change to only `postgres-upgrade`, or a patch-level app image, is low risk. Check the release notes for minor or major app images and for any Postgres major change, because those run migrations.
3. Make sure a recent snapshot of the app's dataset exists. The nightly snapshot taken while the app was stopped is a consistent cold copy.
4. Run `midclt call -j app.start <app>`. It pulls the missing images and starts the app on the new version. Do not use raw `docker compose`, and do not reinstall.
5. Verify `app.query` reports `RUNNING`, every container is `healthy`, and the app works end to end.

Start the SSO provider (Authelia) first. While it is down, every router that uses the `authelia@file` middleware returns HTTP **500**, even when the backend is healthy. Unprotected routes, such as PWA assets, still return 200.

Field notes from the 2026-10-08 recovery of nine apps:

- **Rollback points.** The nightly snapshot task covers `Apps/Applications`, but not `ix-apps/app_mounts/*`. For apps stored there (for example n8n), `app.upgrade` makes its own snapshot named `@<previous chart version>` on the app_mounts datasets before it starts. Check that snapshot's `written` value to confirm it is still a clean rollback point.
- **Start one app at a time.** After each start, check that the app is RUNNING and its containers are healthy, then look for `error|fatal|migrat` in `docker logs --since 10m`. The postgres-upgrade helper should log `Upgrade already completed` when Postgres is staying on the same major version.
- **RomM 5.3.x false lead.** RomM can crash-loop with `Failed to run database migrations`, but the real error is on the line just before it: `CRITICAL ... config_manager ... filesystem.roms_folder is no longer supported`. 5.3 rejects the old `filesystem.roms_folder` key in `config.yml` and wants `filesystem.structure.default: "roms/{platform}/{game}"`. The pinned image digest doesn't change in this case, so the error was already there before the upgrade. Stop the app, back up `config.yml`, and edit it with the owner's approval.
- **Harmless noise:**
  - Warracker logs a gevent `AssertionError: (None, <callback ...>)` when it forks workers.
  - n8n warns that the Python task runner is missing.
  - n8n's `/healthz` is served over HTTPS on its published port, so a plain-HTTP probe gets an empty reply.

## Knock-on effects to check

- **tiredofit/db-backup** dumps its databases one after another. It retries an unreachable host forever (`Postgres Host '<container>' is not accessible, retrying.. (N seconds so far)`), so every database later in the list misses its dump. Once the host is back, the stuck job finishes on its own within seconds and writes the remaining dumps. Check:
  - the newest `latest-*` symlink in each dump directory
  - `zstd -t <file>`
  - `sha1sum -c <file>.sha1`
  - that each size is close to the previous day's
- **Backrest** runs restic as uid/gid 568 (`apps`). Any file in a plan path that `apps` cannot read makes the run `STATUS_WARNING` / `Partial backup`.
  - Use the restic error list from the API to find these files. Busybox `[ -r ]` and `find ! -readable` in the container gave false results here.
  - Fix the narrowest thing, for example `chmod 0640` on a `root:apps 0600` one-off dump. Do not chmod whole trees.
- Backrest API, when auth is disabled on the LAN listener (connect-RPC JSON):
  ```bash
  # recent operations for one plan; failures are in .operationBackup.errors
  curl -s -X POST -H 'Content-Type: application/json' \
    --data '{"selector":{"planId":"<plan>"},"lastN":"5"}' http://${NAS_IP}:${BACKREST_PORT}/v1.Backrest/GetOperations
  # run one plan now (blocks until the backup finishes); this does not change its schedule
  curl -s -X POST -H 'Content-Type: application/json' --data '{"value":"<plan>"}' \
    http://${NAS_IP}:${BACKREST_PORT}/v1.Backrest/Backup
  ```
  Require `STATUS_SUCCESS`, an empty `errors` list, and a new `snapshotId`.
