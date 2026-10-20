# immich-proton-sync: Immich version bump procedure

The `immich-proton-sync` reconciler (locally built custom app; source repo
`immich-proton-sync`) refuses to run a cycle unless Immich's
`GET /server/version` is in `VERIFIED_IMMICH_VERSIONS` in `reconcile.py`.
An unverified version makes every cycle fail with
`ValueError: Immich version changed; review source view before applying`, the
container goes unhealthy, and the TrueNAS app sits in `DEPLOYING`. Nothing is
read from Proton or changed while the guard trips. That is intended: keep the
guard; extend the allowlist only after verification. Never pin Immich instead.

## 1. What to verify

The reconciler depends on:

- **DB view `public.proton_sync_source`** (read by the `proton_sync` role,
  SELECT only): `asset.id, checksum, originalPath, originalFileName, status,
  visibility, ownerId, fileCreatedAt, livePhotoVideoId`; `asset_exif.assetId,
  fileSizeInByte`; `tag_asset.assetId, tagId`; `tag.id, value`; enum values
  `assets_status_enum` = active,trashed,deleted and `asset_visibility_enum` =
  archive,timeline,hidden,locked.
- **API endpoints**: `GET /server/version`, `GET /assets/{id}` (checksum),
  `POST /assets` (upload, only when imports are enabled), `DELETE /assets`
  (`force:false`), `GET/POST /albums`, `PUT /albums/{id}/assets`,
  `POST /trash/restore/assets`.

Checks (all read-only):

1. Release notes for every version in between (GitHub releases API); look for
   asset/trash/album/checksum/visibility/stack changes.
2. Diff the OpenAPI spec (`open-api/immich-openapi-specs.json`) at the old and
   new tags for exactly those path+method pairs and every schema they
   reference (recursive `$ref` walk). Identical = API-compatible.
3. On the live DB inside `BEGIN READ ONLY ... ROLLBACK`: `pg_get_viewdef` of the
   view still matches `source.sql`; `information_schema.columns` for the columns
   above (names, types); `pg_enum` labels; `kysely_migrations` rows added since
   the last verified upgrade (names reveal which tables changed); the view
   grant for `proton_sync` still exists; `status, visibility` counts look sane.
   Pipe SQL to `docker exec -i <immich-postgres> psql -U <db-admin> -d immich -At`
   on stdin; nested shell quoting of SQL literals breaks.

If any input changed, adapt the code/view minimally and add a test.

## 2. Bump, test, build

- Add the tuple to `VERIFIED_IMMICH_VERSIONS` with a dated comment. Keep older
  verified versions (rollback compatibility). Tests in `test_worker.py` cover
  "unverified version stops before any Proton call" and "verified accepted".
- `python -m unittest` in the build dir (psycopg is imported lazily).
- Before building: `docker save <image>:<old> | gzip -1 > build/<image>-<old>.tar.gz`
  and keep `*.tar.gz` in `build/.dockerignore`.
- The weekly NAS image-prune cron (`docker image prune -af --filter until=168h`)
  deletes any image without a container. Protect the old tag with a never-started
  holder container: `docker create --name immich-proton-sync-rollback-hold
  --network none --entrypoint /bin/true <image>:<old>` (recreate it on each bump).
- Verify the pinned Proton CLI SHA512 (README) before building; then
  `docker build -t <image>:<new> .` and smoke-test the allowlist/CLI version
  with `--network none`.

## 3. Dry run (must precede apply)

Back up `state/ledger.sqlite` with the sqlite backup API (it has a WAL). Run the
new image once with the app's mounts and `--entrypoint python` on a diagnostic
script that: copies the ledger to tmpfs and sets `state_dir` there; wraps `cli`
to allow only `photo timeline`, `filesystem info|list`, `album list|photos`;
wraps `api` to allow only GET; calls `Worker.cycle(False, 0)`; prints counts and
error types only (never names/paths). Review `planned`: expect `upload` close to
new Immich assets since the outage, plus a few `retire_recovery`/`save_recovery`.
STOP and escalate on any large `trash_photos`, `retire_*`, or applied
`proton_deletions`.

Known long-lived holds that are not regressions: Proton-only `import` items are
paused by `--import-limit 0`; `size_conflict` groups are held by design; hidden
Live Photo components whose on-disk SHA1 differs from Immich's checksum hold as
`FileNotFoundError` uploads; a mapped Photos UID whose `filesystem info` fails
keeps a `proton_delete_held: RuntimeError` forever (it never deletes in Immich).

## 4. Deploy and watch

Replace the image tag in `versions/<v>/user_config.yaml`,
`versions/<v>/templates/rendered/docker-compose.yaml`, and the app's
`compose.json` (back each up first), then `app.stop` + `app.start`. Confirm
`RUNNING`, container `healthy`, and at least one cycle with `"applied": true`,
`actions_completed > 0` and no `error`. Backlog drains about 8 uploads per cycle
at the deployed budget (12 actions minus 4 reserved).
Rollback: `docker load` the tarball (or use the held tag), restore the tag in
the three files, stop/start.
