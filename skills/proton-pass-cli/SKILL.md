---
name: proton-pass-cli
description: Luke-specific Proton Pass CLI facts — API Credential items, the Agents vault, viewer-role limits, REASON length, v2.5 web login and extra password, the note size limit, stale PAT recovery, and the native export schema. Generic CLI usage comes from pass-cli agent instructions.
author: Luke
---

# Proton Pass CLI

Generic install, login, item read, and `pass://` usage are whatever `pass-cli agent instructions` prints for the installed CLI. Do not follow a vendored Homebrew or `curl | bash` guide. Install with the package order in `direct-action-preferences`.

This skill is only the behavior that the generated instructions get wrong on Luke's account.

## API Credential items

Store API tokens as **API Credential** custom items with fields `API Key`, `Secret`, `Expiry Date`, and `Permissions`, one item per token. Read a field with `--field "API Key"` straight into a mode `0600` file, then a credential helper that reads the file. Never put the value in argv or command output.

## Agents vault and viewer role

Luke's scoped agent token is usually **viewer**. `info`, `vault list`, `item list`, and `item view` work. Creates and updates fail with `NotAllowed`. Do not retry writes through a viewer agent, and do not bootstrap a broader session from secrets that agent can read.

Agent-created credentials belong in the **Agents** vault. Verify the agent can read them after saving. Access grants are an owner-authenticated operation. A viewer session cannot manage agents or PAT grants.

If a value must be used before Luke can save it, keep a root-only `0600` file, say that the Pass save is still pending, and delete the file after Pass-backed use works.

## Audit reason

Audited commands need `PROTON_PASS_AGENT_REASON`. Keep it specific and under 300 characters. Longer reasons are rejected before the operation runs.

## CLI v2.5

From v2.5.0, `pass-cli login` defaults to the web login; there is no password prompt (checked on 2.5.1, 2026-10-29). Its `--pat` option would put the token in argv; use `PROTON_PASS_PERSONAL_ACCESS_TOKEN` instead. Hosts can lag (pve was still on 2.4.1 on 2026-10-29), so check `pass-cli --version`.

The account has an extra password. Commands that need it read `PROTON_PASS_EXTRA_PASSWORD` (or `PROTON_PASS_EXTRA_PASSWORD_FILE`). After `source ~/.config/proton-pass-cli/env`, set it from `PROTON_PASS_LOGIN_EXTRA`:

```bash
export PROTON_PASS_EXTRA_PASSWORD="$PROTON_PASS_LOGIN_EXTRA"
```

Never print either value.

## Note size

`item update` on a note fails with `InvalidValue` at about 39.9 KB. That error looks like a role failure. Check `wc -c` first. On 2026-10-08, 39,815 bytes was accepted and 39,913 bytes was rejected. Split a larger note.

## Stale session

`pass-cli info` can report `non-existent session` while `pass-cli login` says `Already authenticated`. See [stale PAT recovery](references/stale-pat-recovery.md). Do not rotate a working token for that.

## Native export schema

To validate a native ZIP/JSON archive, read the schema from [ProtonMail/WebClients](https://github.com/ProtonMail/WebClients) (authoritative for native JSON) and record the commit inspected. Vault IDs, item IDs, and pin state are not restored. Passkey objects stay opaque.

## Self-maintenance

This is a Luke-authored personal skill. Update it when a verified CLI or account fact here is wrong. Follow `personal-skill-maintenance`. Never record credential values.
