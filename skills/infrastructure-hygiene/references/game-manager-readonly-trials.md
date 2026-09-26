# Read-only RetroArr and Questarr trials

Use this procedure to evaluate game managers without changing canonical ROMs, seeded payloads or retention rules. Verified against RetroArr 1.0.217 and Questarr v1.4.2; re-audit newer versions.

## Isolation and acceptance

- Use native TrueNAS custom apps, pinned official image digests, dedicated app-state binds, no published host ports, and read-only canonical library mounts. Leave download clients absent. Disable extraction, rename/move, automatic grabs and cleanup before populating catalogues.
- Match the actual library-reader UID/GID rather than changing existing library permissions. RetroArr's PUID/PGID environment does not change its Docker USER: set explicit Compose `user` and own only its new config/savestates binds appropriately. Questarr's official root entrypoint adjusts PUID/PGID and drops privileges; keep shared media outside `/app/data`, which the entrypoint may chown recursively.
- Snapshot torrent hashes/paths/categories/limits and file device/inode/size/link-count/mtime before changes. Hash retention-manager configs. Retire only the named old app, preserving its state/managed compose/route for rollback; remove a category/download directory only after proving it empty.
- Use representative platform scans first. Persist each batch, then count/deduplicate programmatically. Catalogue-record totals are not verified unique-game totals. Recreate through TrueNAS and re-read settings, records and storage invariants.

## Authentication: test APIs, not just the homepage

- A browser redirect to Authelia does not prove API protection. Shared access-control policies can bypass `/api` while protecting `/`. Before enabling proxy-injected credentials, test anonymous requests to real catalogue/settings APIs and websocket endpoints through the final hostname.
- Prefer native API authentication. Do not inject an app administrator API key merely because an Authelia middleware precedes it: a bypass policy makes that injection grant anonymous administrative access. If discovered, remove the injection, rotate the app key, prove the old key rejected and new key accepted, and verify anonymous external requests fail. Report the temporary exposure honestly; read-only media does not protect catalogue/settings APIs.
- RetroArr supports API-key login; store the key in the approved password manager. Its bootstrap endpoint is loopback-only. Questarr v1.4.2 requires its own username/password/JWT; it has no supported external/proxy-header/OIDC or auth-disable option. Keep the whole UI/socket route behind Authelia and preserve native API guards.
- A 200 response can be SPA fallback HTML for a nonexistent API route. Require JSON and expected fields, not status alone.

## RetroArr controls and scanner checks

- Disable `Enabled` in monitor settings and `EnableAutoMove`, `EnableAutoExtract`, `EnableDeepClean` in postdownload settings. Keep rename-on-import false and download clients empty.
- Read back `/api/v3/settings/monitor`, `/api/v3/postdownload`, `/api/v3/downloadclient`, `/api/v3/media`. Trigger bounded scans with `POST /api/v3/media/scan` and `folderPath`; poll `/api/v3/media/scan/status`, then read `/api/v3/game`.
- Zero scan results with permission-denied logs are a runtime UID issue, not proof of unsupported formats. Align the new app's user and rescan without chmod/chown of the library.
- Verify PS3 root-folder association, PSP file coverage, platform-matched metadata and exclusion of emulator storage. Successful discovery still permits incorrect metadata, missing matches or emulator directories classified as games.

## Questarr controls and import limitations

- Bootstrap once with `/api/auth/setup`, then explicitly disable `autoSearchEnabled` (defaults true), `autoDownloadEnabled`, `autoSearchUnreleased`, `xrelSceneReleases`, `xrelP2pReleases`, `enablePostProcessing`, `autoUnpack`, `overwriteExisting`, and `autoDeleteAfterImport` through `PATCH /api/settings`. Re-read settings/import config and require no downloaders.
- There is no master scheduler disable. Maintenance/metadata timers still run; describe the disabled actions accurately.
- Disable the default RSS feed using `PUT /api/rss/feeds/<id>` rather than deleting the final feed, which is reseeded at startup.
- Avoid global Prowlarr sync: it imports all compatible feeds and enables RSS/autosearch. Add only live-verified allowed private/freeleech feeds individually via `POST /api/indexers`, with explicit `rssEnabled:false` and `autoSearchEnabled:false`. Do not include unfiltered cross-seed-only feeds. Global auto-search must also remain false.
- Test each indexer and a bounded manual search; distinguish successful search from actual acquisition. No client means no download-to-import proof.
- No supported existing-directory metadata-only scanner was found in v1.4.2. Add a small owned sample with `POST /api/games`, selecting the correct platform/edition through IGDB, not the first search result. Quick Add forces wanted status and is unsuitable for this trial.
- `DatabaseStorage.addGame` omits `libraryPath` and notes despite the schema accepting them. Use the supported `PATCH /api/games/<id>/notes` for provenance and describe records as metadata-only, not file imports.
- Never call manual import confirmation or the hardlink-check endpoint during read-only evaluation; the latter performs test writes. Hardlink mode directly links the source and may fail for directories; cross-device errors can fall back to copies.
