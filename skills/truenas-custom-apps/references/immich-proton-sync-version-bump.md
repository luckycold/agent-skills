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

Known long-lived holds that are not regressions: Proton-only imports run at
`--import-limit 10` (since 2026-10-20; config `import_album` is false, so no
"Imported from Proton" album); `size_conflict` groups are held by design; a
mapped Photos UID whose `filesystem info` fails keeps a
`proton_delete_held: RuntimeError` forever (it never deletes in Immich).

Since 0.1.16, a Proton `claimedSize` that equals the real size modulo 2^32
counts as a match for files of 2 GiB or more (some Proton clients wrote it as
int32, so it wrapped, often negative); the SHA1 must still match. Such files
are no longer `size_conflict` and get linked without a re-upload. Remaining
`size_conflict` groups are genuine (e.g. edited JPEGs whose claimed size is
smaller than the Immich original). The CLI upload path already writes full
64-bit sizes.

Since 0.1.13, Immich-extracted motion clips (hidden, `parents` set, path under
`encoded-video`) are skipped entirely (summary `derived_motion.skipped` /
`in_proton`): the still's original embeds the same bytes. They never upload and
never drive deletion/restore mirroring. `in_proton` should stay at the 3 kept
standalone clips whose stills Luke deleted in Proton. Separate live-photo
originals (iPhone `.MOV`) still upload unpaired.

Since 0.1.14, uploads go through the thumbnail-capable fork
when config `proton_cli_thumbs` = `/usr/local/bin/proton-drive-thumbs` (a
wrapper that sets XDG dirs to `/state/thumbs-cli` and execs
`proton-drive-labby`, build `external-drive-labby_photos@1.0.0-stable+cli090.thumbs3`;
patches in the repo's `proton-cli/patches/`). Video thumbnails come from an
ffmpeg frame, HEIC from heif-convert, and undecodable JPEGs from an ffmpeg
re-encode (0.1.15). Failures log `thumbs_upload_failed` and fall back to the
official CLI. The fork has its OWN session: if it expires, run
`proton-drive-thumbs auth login` in a one-off container with `/state` mounted,
hand Luke the sign-in URL (write it to a 600 file, never print it); polling lasts
30 min. Check locally, with no upload or sign-in:
`docker exec <c> proton-drive-thumbs photo thumbnail-test -o /tmp/tt <file>`.
Check a node's thumbnails with `proton-drive-thumbs photo thumbnails /photos/<uid> --json`.
Replacing a thumbless node: upload a new copy (`--conflict-strategy rename`),
verify sha1, size, capture time and thumbnails, wait until the ledger
`photo_uids` includes the new uid, trash the old node, then rename the new node
back. The same content is never absent, so no deletion is mirrored. The
2026-10-20 run (256 replaced) used `state/thumbs-replace/replace_thumbs.py` on the NAS.
The container cannot read `.zfs/snapshot` (ELOOP), so the `original()` snapshot
fallback only works on the host. 2026-10-20 audit and cleanup notes:
`/workspace/homelab/proton-motion-thumbs/README.md` on the Labby box.

## 4. Deploy and watch

Preferred (0.1.13+): back up `midclt call app.config immich-proton-sync`, change
only `services.reconciler.image` in that JSON, and apply it with
`midclt call -j app.update immich-proton-sync '{"custom_compose_config": <json>}'`
(regenerates the rendered files and redeploys); then update the reference
`compose.json`. Older manual way: replace the tag in `versions/<v>/user_config.yaml`,
`versions/<v>/templates/rendered/docker-compose.yaml`, and the app's
`compose.json` (back each up first), then `app.stop` + `app.start`. Confirm
`RUNNING`, container `healthy`, and at least one cycle with `"applied": true`,
`actions_completed > 0` and no `error`. Backlog drains about 8 uploads per cycle
at the deployed budget (12 actions minus 4 reserved).
Rollback: `docker load` the tarball (or use the held tag), restore the tag
(app.update with the backed-up config, or the three files), stop/start. Holders
exist per version (`immich-proton-sync-rollback-hold` = 0.1.11,
`immich-proton-sync-rollback-hold-0.1.12`, `-0.1.13`, `-0.1.14`, `-0.1.15`); tarballs live in
`build/immich-proton-sync-<v>.tar.gz` with sources in `build-<v>-src/`. Back up
the ledger with the sqlite backup API (it runs in WAL mode), not `cp`.
Restarting with app.update between cycles costs about 13 s of downtime.
