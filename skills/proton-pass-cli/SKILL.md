---
name: proton-pass-cli
description: Set up and use the official Proton Pass CLI for scoped, audited agent access to secrets in headless/container Hermes environments.
author: Luke
---

# Proton Pass CLI

Use this skill when setting up, troubleshooting, or using Proton Pass from Hermes/CLI, especially for agent-scoped secret access.

## Preferred Approach

1. **Install the official CLI conventionally.** Prefer Homebrew when available:
   ```bash
   brew tap protonpass/tap
   brew install protonpass/tap/pass-cli
   pass-cli --version
   ```
   The installed binary is `pass-cli`.

2. **Use container-safe local storage.** In Home Assistant add-ons, Docker containers, and other headless environments, avoid assuming a desktop keyring or persistent Linux kernel keyring. Set a dedicated session dir and filesystem key provider:
   ```bash
   export PROTON_PASS_SESSION_DIR="<persistent-session-dir>"
   export PROTON_PASS_KEY_PROVIDER=fs
   export PROTON_PASS_DISABLE_TELEMETRY=1
   export PASS_LOG_LEVEL=warn
   ```
   Lock down the state directory and files with `0700` dirs and `0600` files.

3. **Create a wrapper instead of scattering env vars.** Use a dedicated local wrapper that sets PATH, `PROTON_PASS_SESSION_DIR`, `PROTON_PASS_KEY_PROVIDER=fs`, quiet logging, and telemetry opt-out before execing `pass-cli`. Resolve Luke's exact wrapper and state paths from `~/.agents/private-context.md`.

4. **Prefer agent tokens for Hermes.** Proton Pass CLI 2.x supports `pass-cli agent ...`, which is better than a broad full-account session for autonomous agents. Agents are scoped, expiring personal access tokens with access logs. Use:
   ```bash
   pass-cli agent create --expiration 1m "Hermes"
   pass-cli agent access grant "Hermes" --vault-name "..." --role viewer
   pass-cli agent instructions "Hermes"
   ```
   Exact commands and flags may vary by CLI version; run `pass-cli agent --help` before issuing side-effecting commands.

5. **Always provide an audit reason for agent reads/writes.** Agent sessions require `PROTON_PASS_AGENT_REASON` for audited operations such as `item view`, item create/update/trash/move, and vault update:
   ```bash
   PROTON_PASS_AGENT_REASON="Need SSH key to troubleshoot Proxmox" pass-cli item view \
     --vault-name "<vault>" \
     --item-title "<ssh-item>" \
     --field password
   ```

6. **Use secret references for command execution.** For scripts or env injection, prefer `pass-cli run` / `pass-cli inject` with `pass://SHARE_ID/ITEM_ID[/FIELD]` references so secrets do not get printed or stored in shell history.

## Security Rules

- Never store or repeat Proton credentials, personal access tokens, agent tokens, callback payloads, passwords, public-share passwords/fragments, archive passwords, or item secret values in memory, skills, or final summaries. Treat one-time delivery passwords as credentials too; if one is accidentally persisted, delete that memory immediately and disclose the cleanup to the user.
- Redact token-like strings as `[REDACTED]`.
- Do not pass PATs on the command line if an environment variable or file-based handoff is available; command-line args may leak via process listings or history.
- If a user pastes a PAT in chat and asks to save it, do not save the literal token; use the existing secure env file/wrapper path or ask for a secure handoff if needed.
- Prefer viewer-scoped, item- or vault-limited access with short expiration.
- Store API tokens as **API Credential** custom items with fields `API Key`, `Secret`, `Expiry Date`, `Permissions`, one item per token, so Luke can see what each token can do and when it expires. Read a field with `--field "API Key"`; never echo it.
- Before granting broad vault access or editor/manager roles, confirm the intended scope with the user.

## Browser sign-in and passkey-only records

- Inspect whether a login contains a password, TOTP, or passkeys before attempting sign-in. A saved login can contain a passkey without a password; do not submit an empty password or treat this as a bad credential.
- The CLI can read passkey data but does not provide browser passkey authentication. Use a browser with the configured passkey provider, or have the user complete that sign-in. Do not export passkey private material to invent an authentication workaround.
- When the user requests their main browser, inspect it through the configured browser integration and use its existing password-manager provider. A separate collaborative preview has its own authentication state; do not infer the main browser's sign-in state from it.
- Keep credential values inside the current secret-injection or browser-fill operation. Report only whether each required field is present.

## Session Discipline

Before any `pass-cli` command, verify the session with `pass-cli info` or the Hermes wrapper equivalent. If it fails with an authentication/session error, read the full output, run `pass-cli logout --force` if needed, re-authenticate via the secure PAT env/wrapper (not by printing or saving the token), verify `pass-cli info`, then retry the original command. During long-running tasks, check `info` periodically. After login/setup, verify access with:

```bash
pass-cli vault list --output json
pass-cli share list --output json
```

For a rejected server session that still appears locally authenticated, see [stale PAT session recovery](references/stale-pat-recovery.md).

## Verification

After setup/login:

```bash
proton-pass-agent --version
proton-pass-agent info
PROTON_PASS_AGENT_REASON="Verification read" proton-pass-agent item view --help
```

For unauthenticated setups, `pass-cli info` should fail cleanly with an authenticated-client error.

For Git SSH auth on a headless host (native `ssh-agent daemon` via the scoped wrapper) and for missing or corrupted local sessions in a headless add-on, see [headless recovery and SSH agent](references/headless-recovery-and-ssh-agent.md).

## CLI v2.5.0 login notes

- v2.5.0 (box, 2026-10-20) signs in through the web login only; there is no password prompt flow.
- The account has an extra (second) password. Commands that need it read `PROTON_PASS_EXTRA_PASSWORD`.
  After `source ~/.config/proton-pass-cli/env`, set it from the env var `PROTON_PASS_LOGIN_EXTRA`
  (`export PROTON_PASS_EXTRA_PASSWORD="$PROTON_PASS_LOGIN_EXTRA"`). Never print either value.
- Read an API Credential field straight into a 0600 file (`--field "API Key" > file`), then use
  it through a credential helper that reads the file. Never put it in argv or the output.
- Older-version syntax quirks (v2.1.0 positional vault for `item list`, alias-vs-login lookups, JSON control characters): see [CLI version notes](references/cli-version-notes.md), which also repeats the v2.5.0 notes above.

## Agent roles, writes, and REASON

- Luke's scoped agent token is usually **viewer** only: `info`, `vault list`, `item list`, `item view` work; creates/updates fail with `NotAllowed`. Do not retry writes through a viewer agent or bootstrap a broader session to bypass it.
- Agent-created credentials belong in the **Agents** vault; verify the agent can read them after saving.
- Keep `PROTON_PASS_AGENT_REASON` short (under ~300 characters) and specific.
- `item update` on a note fails with `InvalidValue` at about 39.9 KB; check `wc -c` and split large notes.
- When a phone approval arrives after a timeout, reissue the operation; delayed approval is not refusal.

Details, owner-only grant operations, the temporary root-only handoff pattern, and the one-shot API key pattern: [agent roles and writes](references/agent-roles-and-writes.md).

## Vault migration, native archives, and reconciliation

Do not import one populated vault directly over another when deduplication is required; reconcile exports locally first. Overview and rules: [vault migration](references/vault-migration.md).

## References

- `references/cli-version-notes.md` — v2.5.0 web login + extra password, v2.1.0 syntax quirks.
- `references/agent-roles-and-writes.md` — viewer-role limits, Agents vault, REASON length, note size limit, one-shot API key pattern.
- `references/headless-recovery-and-ssh-agent.md` — headless session recovery and scoped SSH agent for Git.
- `references/stale-pat-recovery.md` — rejected server session that still looks authenticated locally.
- `references/vault-migration.md` — migration overview and pointers.
- `references/cli-duplicate-cleanup.md` — authorized in-place duplicate cleanup with trash-only operations.
- `references/bitwarden-roundtrip-migration.md` — safe Bitwarden↔Proton reconciliation, trash/alias semantics, and passkey-portability research.
- `references/passkey-canary-and-secure-handoff.md` — disposable one-entry migration test, Proton-native passkey validation, and AES-protected delivery using `pass-cli run` secret injection.
- `references/native-export-schema.md` — commit-pinned Proton native ZIP/JSON schema, field paths, timestamp and vault behavior, opaque passkey format, attachment naming, and import-validation pitfalls.
- `references/proton-drive-public-share-retrieval.md` — secure public-share export download workflow and current browser-automation compatibility fixes.
- `references/browser-stdin-injection.md` — scoped native `run` usage and OTP input behavior.
- See the `himalaya` skill's `references/proton-pass-agent-wrapper-for-himalaya.md` for a production wrapper that drives the agent (with REASON) to supply the Proton Bridge credential to himalaya in headless/cron runs.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical package under `~/.agents/skills/` when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Make the smallest evidence-backed edit, never record credentials or secret values, and do not infer a durable preference from one request. Follow the `personal-skill-maintenance` skill for the full review and verification workflow.
