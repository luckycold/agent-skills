# Vault migration, native archives, and reconciliation

Linked from the proton-pass-cli skill.

For authorized in-place duplicate cleanup, see [CLI duplicate cleanup](cli-duplicate-cleanup.md) for full-content inventory, conservative matching, URL preservation, trash-only operations, and final reconciliation.

For password-manager round trips, do not import one populated vault directly over another when deduplication is required. Export both sides, reconcile locally into a clean native Proton archive, preserve conflicting older copies in a review vault, and verify before retiring either source. Treat third-party passkey conversion as experimental until each credential authenticates successfully against its real relying party.

When generating or validating a native archive, derive the contract from commit-pinned `proton-webclients` export/import source rather than guessing from example exports. Do not access user exports unless explicitly authorized; use source inspection and synthetic fixtures. Preserve Proton passkey objects as opaque Base64/MessagePack state. Remember that vault IDs, item IDs, pin state, vault display metadata, and input content-format versions are not restored, and attachment linking can advance the backend-controlled final modification time.
