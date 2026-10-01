# In-place duplicate cleanup through the official CLI

Use only when the user authorizes inventory and cleanup. Prefer the existing authenticated CLI session; do not bootstrap owner access from secrets readable by a viewer agent.

## Inventory and access

- Inspect `pass-cli --version`, `info`, `vault list --output json`, `share list --output json`, and each relevant subcommand's `--help`.
- A locally authenticated personal-access-token session can have Manager access. Distinguish it from an AI-agent session and inspect its actual grants; do not assume every token is a viewer or that its visible vaults cover the entire account.
- Versions 2.3.3 and 2.4.2 support `item list --share-id <share-id> --output json --show-secrets`. The CLI explicitly disallows `--show-secrets` for agent sessions. Ordinary JSON item listings omit credential contents.
- Capture output directly into a restricted local working area, preferably a user-private RAM-backed directory. Use `0700` directories and `0600` files. Do not send raw inventories, credentials, identifiers, password hashes, or TOTP/passkey material to chat or external tools. Emit only counts, field names, and necessary item titles.
- Record the initial trash set explicitly with `--filter-state trashed`. Do not assume trash is empty.
- Version 2.3.3 omits newer `autofill_urls` and `custom_icon` fields that 2.4.2 exposes. Compare a complete current schema before changing items; use the supported official updater where needed, then repeat the inventory.

## Conservative matching

- Compare the entire item content, including username, email, password, raw TOTP URI, notes, custom fields, passkeys, Android app associations, URL matching modes, and icons. Ignore generated item UUIDs and timestamps for content equality; keep timestamps for audit and deterministic survivor selection.
- Do not case-fold passwords or silently treat username and email fields as interchangeable. Empty credentials are insufficient evidence of duplication.
- Keep unrelated sites separate unless the user explicitly requests combining them. Identical reused credentials can form large cross-site clusters. Similar titles, related SSO hosts, or a shared hosting domain do not prove the same account.
- URL-only differences can be merged after establishing the same site/account and equality of every other relevant field. Different display titles can be acceptable when the same site and complete content match; preserve a useful survivor title.
- Flag differing notes, credentials, TOTP, passkeys, app associations, and custom fields for review. Do not silently discard a value because another copy lacks it.
- Treat aliases separately: an alias is a live mail-routing object, not a duplicate login just because its title resembles one. Exclude attachments and unfamiliar flags from automatic cleanup unless their contents and effects have been verified.

## URL updates and reversible removal

- Re-read each candidate with `item view --share-id <share-id> --item-id <item-id> --output json` before mutation. Its JSON contains `item` and `attachments`. Stop if content/state changed or attachments appeared after inventory.
- Verified in 2.4.2: the built-in login field is **`urls`**, plural, with a comma-separated value. The documentation's singular `url` example can instead create a custom field. Check source and read back the result; command success alone is insufficient.
- The verified merge path starts with empty `autofill_urls` and legacy URL lists. `--field 'urls=<complete-union>'` preserves the legacy union and creates corresponding Default autofill rules. Reject URLs containing commas, leading/trailing whitespace, or secret-bearing components that would be exposed in argv.
- Existing nonempty `autofill_urls` need separate handling: changing legacy `urls` is not proof that the effective autofill rules changed. Do not flatten nondefault modes. Use a supported client capable of preserving those rules.
- After updating, verify the complete URL union in both fields and exact preservation of every other content field before trashing any copy.
- Use `item trash`, never `item delete`; the latter permanently deletes. Verify each removed item is Trashed with unchanged content and each survivor is Active. `item untrash` is the recovery command.
- Keep a private local journal mapping each trashed item to its survivor, without credential values. Reconcile the final active/trash ID sets with the initial sets, verify merged content, and confirm all unaffected items retain their content.
- Produce a report containing changes and unresolved field differences, then remove temporary plaintext inventories after verification. Leave trash for the user to review.

## Source checkpoints

- CLI: `protonpass/pass-cli`, tag `2.4.2`; item list/view/update/trash command implementations.
- Content model: `protonpass/proton-pass-common`, tag `2.1.1`, commit `25b673b98ed84982e74a1fbcdf036ebd7957950f`; `proton-pass-types/src/models/item/mod.rs` (`update_login_field`, `perform_update`, and login serialization).
- Re-check behavior against the installed version before subsequent cleanup runs.
