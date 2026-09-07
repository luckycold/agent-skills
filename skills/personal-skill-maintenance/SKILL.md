---
name: "personal-skill-maintenance"
description: "Maintain personal Agent Skills after verified workflows, corrections, or requests to capture reusable procedures; validate and publish safe library updates."
author: Luke
---

# Personal Skill Maintenance

Treat Luke-authored personal skills as writable procedural memory shared across agents.

## Scope

- The canonical cross-agent working agreement and personal-skill index is `~/.agents/AGENTS.md`; tool-specific global instruction paths resolve to it or instruct the agent to load it.
- The canonical library is `~/.agents/skills/`.
- A skill is personal and writable only when its `SKILL.md` frontmatter contains `author: Luke`.
- Codex, Cursor, and OpenCode discover the canonical standard skill path directly. Claude's required `~/.claude/skills/` entries resolve to the same packages. Never create divergent copies.
- Do not self-modify third-party, bundled, system, or project-owned skills.

## Session start

For a writable OpenClaw Git checkout, inspect `git status --short` and fetch through `gateway_exec` once per session; fast-forward only a clean checkout with `git pull --ff-only`. Preserve uncommitted work and resolve divergence before publishing. Do not run a copy-based installer over the shared checkout.

For separately installed copies on other hosts, at the start of each new run, refresh installed copies of this library with `update-agent-skills` (the skills.sh CLI) before other work. In non-interactive shells, source `${DOTFILES_DIR:-$HOME/dotfiles}/common/.bashrc.d/dotfiles_management.bash` in the same command first. Skip if this session already ran it. If Node.js or npm is missing, report that and continue with on-disk skills.

## When to learn

Update or create a personal skill when at least one is true:

- A non-trivial, repeatable multi-step workflow succeeded.
- Earlier steps failed and evidence established a durable working path.
- Luke corrected the approach or stated a durable preference.
- A loaded personal skill is materially wrong, incomplete, stale, or overly narrow.

Do not write a skill for a one-off result, transient status, speculation, or information the agent has not verified.

## Workflow

1. Inspect the loaded skill and its directly referenced support files. For OpenClaw, follow the integration and publication steps below.
2. Identify the smallest reusable lesson and the evidence supporting it.
3. Prefer a targeted edit:
   - Patch `SKILL.md` for a concise rule or procedure.
   - Add or update one directly linked reference for detailed commands or examples.
   - Create a new skill only when no existing Luke-authored skill is a natural home.
4. Apply the safety filter below.
5. Verify frontmatter, relative links, commands, and consistency with the observed system.
6. Run the canonical repository's public-safety check and treat any finding as blocking.
7. Review the repository diff, commit and push the safe verified change to `luckycold/agent-skills`.
8. In the user-facing final response, explicitly name every skill created or updated and include the resulting pushed commit. Never leave a skill change implicit.

## OpenClaw integration and publication

1. Keep one Git checkout. Point `~/.agents/skills` and a workspace `skills/` entry to its skills directory; trust only that target with `skills.load.allowSymlinkTargets`, enable `skills.workshop.allowSymlinkTargetWrites`, and keep watching enabled. Avoid loading the same checkout again through `extraDirs`. Link `~/.agents/AGENTS.md` to the checkout's working agreement.
2. Verify OpenClaw discovery with `openclaw skills info <skill> --json` and native Codex discovery with app-server `skills/list` using the actual workspace and `forceReload: true`. Directory eligibility alone does not prove native catalog visibility; recheck in a new turn if the active catalog is stale.
3. Read and update through Skill Workshop. Pass the intended full `description` explicitly when changing it: Workshop proposal metadata controls the applied frontmatter. Preserve supporting files and inspect the complete proposed result.
4. Keep imported skills user-authored. They lack Workshop-create provenance, so agent-tool apply can reject ownership. For an operator-authorized update, including Luke's standing safe-maintenance authorization, use the supported `openclaw skills workshop apply <proposal-id> --agent <agent-id> --json` route; verify applied status and the scanner result. Do not fabricate ownership records, bypass scanning, or edit live skills directly. Without applicable authorization, leave the proposal pending and report the restriction.
5. Check `github_identity_status`, then run `gh api user --jq .login` through `gateway_exec`. Managed login does not install a Git credential helper. Inspect existing repository credential configuration; where none exists, set the repository-local `credential.https://github.com.helper` to `!gh auth git-credential`. Verify with `git push --dry-run origin HEAD:main`.
6. Run authenticated Git commands through `gateway_exec`, which binds managed credentials privately at process launch. Native Codex shell does not provide that guarantee. Commit and push only after the public-safety check and diff validation; verify the remote commit and clean working tree. If login is unavailable, use Settings → Profile → GitHub connections → System GitHub; keep credentials and device codes out of chat.

## Safety filter

- Never store passwords, tokens, private keys, session material, recovery data, or raw secret-manager identifiers.
- Do not add new personal identifiers, private hostnames, IP addresses, emails, device IDs, or infrastructure topology unless they are necessary to the reusable procedure and Luke has approved tracking that class of data.
- Generalize examples where exact values are not required.
- Do not convert a single request into a permanent preference.
- Preserve explicit hard rules unless Luke changes them.
- If sensitivity or durability is unclear, ask Luke instead of writing.
- Put approved private operational values in the Proton Pass-backed `~/.agents/private-context.md`, not in a skill. Keep only descriptive placeholders and the reusable procedure in version control.

## Creating a personal skill

- Use a lowercase hyphenated name and a directory containing `SKILL.md`.
- Include `name`, a specific trigger-oriented `description`, and `author: Luke`.
- Keep `SKILL.md` concise and place detailed material in directly linked `references/`, `scripts/`, `templates/`, or `assets/`.
- Include a `Self-maintenance` section pointing back to this skill.
- Luke has authorized safe personal-skill changes to be committed and pushed to `luckycold/agent-skills` without asking each time. Never push when validation or the public-safety scan fails.

## Curation

Ordinary Agent Skills have no portable usage counter, background review fork, archive ledger, or approval queue. Git provides review and rollback for this shared library.

- Never auto-delete or auto-archive a personal skill based only on apparent non-use.
- If two personal skills overlap substantially, propose or perform a conservative consolidation only when the current task establishes that it is safe.
- Preserve whole packages and repair relative links when consolidating.

## Self-maintenance

This skill may update itself when a verified change to agent discovery, skill portability, or the shared maintenance policy makes these instructions inaccurate. Apply the same evidence, safety, validation, and authorized-push rules above.
