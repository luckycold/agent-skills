# Agent roles, write operations, and REASON constraints

Linked from the proton-pass-cli skill.

Credentials created by the agent belong in the **Agents** vault, rather than
Main or another vault containing user-created items. Verify that the configured
agent can read the destination after saving or moving the item; the correct
vault name does not itself grant access. Do not expand token permissions merely
to make storage convenient. An already user-authenticated Proton Pass browser
can perform the requested create or move while the CLI remains viewer-scoped.
If that browser disconnects, keep the protected temporary handoff and report
the unfinished move instead of claiming it succeeded.

Agent and personal-access-token sessions cannot manage agents or PAT grants,
even with an editor vault role. Run access grants from an owner-authenticated
CLI. Whole-vault read/write uses `--role editor` without item flags. Preserve
the existing agent session when arranging an owner login; a web login can
still require human reauthentication despite an already signed-in browser.
For authorized editor writes, use `item create login --from-template -` with
JSON on stdin, then verify the saved vault and secret. Avoid passwords in argv.

Luke's scoped agent token is usually granted only **viewer** role for least privilege. Resolve its local wrapper and approved vault scope from `~/.agents/private-context.md`. This is safe for discovery but restrictive for writes:

- Successful with REASON: `info`, `vault list`, `item list "<Vault>" --output json`, `item view`.
- Fails with "Could not perform operation. Reason: NotAllowed" (or similar): `item create`, `item create note`, `item update`, adding custom fields, or editing existing logins/aliases.

When a task requires persisting a discovered secret, use the agent **only for read/discovery**. After the user supplies the value, perform the actual storage manually in the Proton Pass app as a purpose-named note or custom field on the appropriate item. Resolve existing item and alias names from the private context; do not keep retrying writes through a viewer agent.

Likewise, do not use account credentials readable by the viewer agent to bootstrap a broad owner/full-account CLI session merely to bypass the viewer role. If a generated operational credential must be consumed before a human can save it in Pass, use a narrowly scoped root-only local secret (`0700` parent, `0600` file), keep it out of logs and argv, clearly report the remaining manual Pass-save step, and remove the local copy after Pass-backed injection is verified. This is a temporary handoff pattern, not a replacement for Proton Pass.

**Note size limit.** `item update --field "note=…"` fails with `Could not perform operation. Reason: InvalidValue` once the note body reaches about 39.9 KB. On 2026-10-08, 39,815 bytes was accepted and 39,913 bytes was rejected. The same error is easy to mistake for a role problem. Before syncing a large note such as the shared private context, check `wc -c`; compact it or split it into a second note, then read it back and confirm it matches.

`PROTON_PASS_AGENT_REASON` must be short (< ~300 characters). Overly long or narrative reasons are rejected at the agent layer before the operation is attempted. Keep them concise and specific (e.g. "Locate UniFi API key for router DHCP DNS fix").

**Proven one-shot pattern for API keys (observed in router DHCP work):**
1. Agent + short REASON to list and locate the item (redact IDs in summaries).
2. User pastes or confirms the key value in chat.
3. Use directly in terminal for the duration of the task only: `export KEY=...; curl -k -H "X-API-Key: $KEY" ...` (never echo the value, never write it to files or memory).
4. Redact the literal key as `[REDACTED]` in all tool output, thinking, and final messages.
5. Tell the user to add it manually in the app for future use.

This pattern keeps the audit trail while respecting role limits.
