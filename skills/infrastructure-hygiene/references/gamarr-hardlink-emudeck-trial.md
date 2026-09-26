# Gamarr hardlink / EmuDeck trial

Use a pinned official image and native TrueNAS custom-app registration; keep app state on Apps and one common media bind matching the download client. Verify actual release image digest rather than trusting `/api/health` version: reviewed v1.3.0 reports a hardcoded 1.0.0.

## Safety gates
- Set `IMPORT_MODE=hardlink`, `IMPORT_HARDLINK_FALLBACK=error`, `REMOVE_TORRENT_AFTER_IMPORT=false`; defaults otherwise MOVE. Disable scheduler, scheduler auto-download, watcher, AI and auto-upgrade for a first trial. Select an unused dedicated qBittorrent category; do not recategorize existing torrents.
- With nonempty `QB_URL`, startup recovery still runs even when watcher is disabled. It starts workers for incomplete category torrents. For true catalog-only mode, explicitly set `QB_URL=""`; an omitted value defaults to a client URL.
- Category filtering protects enumeration, not arbitrary mutations: the reviewed direct torrent-delete API accepts any hash. Safety rejection paths can delete payloads even when post-import removal is false. Never present category selection as an API authorization boundary.
- Prowlarr IDs must be verified from the user's existing configuration. Its allowlist does not disable built-in Myrient/Vimm direct-download sources. Preserve private-tracker filters and do not select a cross-seed-only indexer for new acquisitions without approval.
- Use a protected reverse-proxy route with no directly published backend. OIDC alone does not secure an unclaimed instance; first-user registration can claim admin. Avoid Docker socket access for a basic trial.
- Runtime `DATA_DIR/settings.json` overrides import mode and archive extraction. Read `/api/settings` after deployment/restart. If a user changes a setting during work, ask before overwriting it. Extraction creates new uncompressed bytes even when archive imports are hardlinked.

## Catalog and filesystem import are different
- Startup scanning writes catalogue records, not payloads. `POST /api/import/scan` with `{"directory":"<real directory>"}` previews files; ISO platform inference uses filenames, not the containing directory.
- `POST /api/import/library` with `{"items":[...]}` inserts metadata only. Validate real paths, measured sizes and titles yourself; this endpoint does not validate files.
- `POST /api/import/files` with `{"files":[{"path":"...","title":"...","platform":"PSP","platform_slug":"psp","is_pc":false}]}` executes the configured filesystem import. For ROMs, slug is used literally as the destination directory.
- `GET /api/settings/import-check` performs temporary filesystem writes and hardlink probes; it is not read-only despite being GET.
- Stock v1.3.0 scanner ignores individual ROMs below 1,000,000 bytes. Supplement real omitted NES/GBA ROMs through metadata-only imports with stable IDs. Do not inflate counts using placeholders.
- Folder games are recognized by immediate child extensions, not console structure. A PS3 game can be catalogued as `USRDIR`; collection directories may collapse into one item. Correct only verified entries, not all recursive executable/ROM-looking files.
- For a supported-API catalogue correction, export first, remove only the incorrect DB record via `DELETE /api/library/{id}`, then import the corrected record. Preserve its opaque `source_id` dedup identity and record original scanner path in metadata; use `source=manual` so startup cleanup does not discard it. Read back the exact row and redeploy to verify no duplicate scan record returns. Never use torrent-delete for this.
- There is no general library platform-folder mapping in the reviewed release: `ngc`/`dc` can differ from EmuDeck `gamecube`/`dreamcast`. Source-registry platform maps are download-source maps, not filesystem destinations. Keep unattended imports off for mismatched platforms; do not conceal this with arbitrary migrations or extra copy trees.

## Verification
- Snapshot existing torrent identity/path/category/limits, qbit_manage config hashes and library device/inode/size/link count/mtime.
- Exercise the real pinned application's import API in a disposable instance with client integration disabled, actual loose-ROM and multifile-game bytes, same UID and common bind layout. Require each destination's device/inode to equal source, then remove only the disposable links/container and assert original link counts return.
- Export the complete catalogue and verify declared counts programmatically; restart and compare stable record fields, not regenerated row IDs.
- Recheck all captured existing torrent/file/config fields after testing. Distinguish connection/search success from a positive acquisition-to-seeding test. Zero search results are not a working release match.
- Document scanner gaps, untested platforms, extraction storage overhead and disabled automation honestly. Keep operation/rollback artifacts beside app state; never put credentials in the skill.
