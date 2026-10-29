# Immich / Proton Drive CLI verification

These behaviors were verified with official Proton Drive CLI 0.9.0 and Immich
3.2.4. Recheck upstream commands and pinned versions before reuse. Resolve host
targets and credentials locally; never put them in this reference.

## Read the correct native representation

- `photo timeline --load-details --json` returns detailed nodes with `uid`.
- `album photos '/albums/<album-uid>' --load-details --json` is required when
  consuming detailed nodes. Without the flag, album entries use `nodeUid`;
  treating them as detailed nodes can fail an otherwise successful cycle.
- `filesystem info '/photos/<photo-uid>' --json` accepts the exact mapped UID
  even after trashing. Its `trashTime` proves native trash status; a missing
  timeline entry alone proves neither deletion nor intent.
- `/photos-trash/<value>` resolves a name, not an exact UID. Do not use it to
  automate restore or permanent deletion of a mapped photo.
- Download each photo UID into a separate directory and verify the actual
  original's SHA1. Same-named batch downloads can overwrite files.
- `filesystem trash --json` can exit zero while returning a failed per-node
  result. Require the expected UID and `ok: true` before recording success.
  Retain recovery folders' returned UIDs for later verification; native
  `filesystem info '/my-files/<node-uid>'` can inspect a trashed folder directly
  without traversing a potentially large regular Trash inventory.

## Verify state transitions, not just final state

Record the requested policy before implementing either direction of deletion.
For an authorized Proton-to-Immich Trash policy, require a previously mapped UID,
matching content hash and size, explicit native trash confirmation on separate
checks, fresh Immich identity/privacy checks, and a verified recovery copy before
using `DELETE /assets` with `force: false`. Hold ambiguous duplicates and failed
proofs. Keep historical baseline deletions separate from new user actions and
exclude the worker's own Photos trash operations from reverse propagation.
When a complete inventory observes a restored active Photos copy, cancel its
pending deletion and clear the upload-suppression flag. Test trash, restore, and
trash again through full cycles: clearing only the pending record can silently
prevent a later legitimate trash action from propagating. Document whether
restoring in Proton after Immich is already trashed restores Immich or is
overridden by Immich's source-of-truth state.
For authorized reverse restoration, confirm that a previously trashed mapped
Photos UID is active again, then restore the same unique Immich ID using
`POST /trash/restore/assets` and verify its active status. This uses `asset.delete`
in the inspected release. Hold the restored Photos copy during confirmation so
the normal trash planner cannot immediately undo the user's restoration. Never
replace a permanently missing Immich item or resolve duplicate ambiguity by
silently importing another copy; keep regular My Files Trash outside this flow.

Immich's delete endpoint needs `asset.delete` and can return an empty HTTP 204;
do not unconditionally parse its response as JSON. Album asset membership uses
the permission spelling `albumAsset.create`.

Trash followed by permanent deletion can happen between polling cycles. Retain
original metadata and last mapped UIDs, recover verified bytes from read-only
source/snapshots or mapped Proton originals, and persist retirement after success
so subsequent cycles do not recreate recovery files. A failed recovery must hold
cleanup. Give newly observed changes priority over initial backfill.

For manual lock/unlock and archive/unarchive tests, leave each state in place
through a completed cycle. A correct final state cannot prove that polling saw
an intermediate state. Container health alone does not prove these workflows.

## Maintained filesystem backups

With `traktuner/docker-proton-drive-backup`, a failed initial whole-folder seed
can be retried through its stock per-file catalog mode by adding appropriate
native exclusions such as `.zfs` and `.immich`; exclusions disable bulk seed in
the inspected upstream engine. Prefer native configuration over a fork.

New catalog file rows can have a null SHA1. Verify downloaded backup bytes against
the actual source file, rather than treating that null as a checksum failure.
Back up the current and future TrueNAS app configurations without automatically
uploading every obsolete pre-existing app version. Stage verified historical
sidecars when long-running uploads would otherwise depend on mounted snapshots.

Native `/config/backup-sets.json` import uses the exported format: a `version`
and `backupSets` wrapper with `sources`, `target`, `targetFolder`, and `time`.
Do not substitute live API/database field names such as `sourcePaths` or
`scheduleHour`. Weekly `dayOfWeek` values are `Sun` through `Sat`; a full weekday
name can silently fall back to Monday in the inspected importer.

Ordinary Immich `pg_dump` backups do not create PostgreSQL roles. If a backup
contains a custom read-only view grant, pre-create its grantee role before an
isolated restore test. Follow the matching Immich release's restore procedure.

## Trigger (formerly in SKILL.md)

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

For Immich backups using the official Proton Drive CLI, see `references/immich-proton-cli-verification.md` for verified JSON formats, deletion proofs, polling tests, and maintained filesystem-backup pitfalls.
