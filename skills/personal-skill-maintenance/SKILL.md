---
name: personal-skill-maintenance
description: Maintain Luke-authored Agent Skills after a verified workflow or correction. Covers when to learn, the public-safety filter, the size check, and pushing with the Pass-backed GitHub PAT.
author: Luke
---

# Personal skill maintenance

Luke-authored skills are writable procedural memory. A skill is personal when its `SKILL.md` frontmatter contains `author: Luke`. Do not edit third-party, bundled, system, or project-owned skills.

Luke authorizes safe, verified updates to `luckycold/agent-skills` without asking each time. Push only after the safety scan passes. Name every changed skill and the pushed commit in the final response.

The working agreement is `~/.agents/AGENTS.md` from Luke's dotfiles. Installation (skills.sh) is in this repository's `README.md`. This skill is the maintenance procedure.

## When to learn

Update or create a personal skill when at least one is true:

- A non-trivial, repeatable multi-step workflow succeeded.
- Earlier steps failed and evidence established a durable working path.
- Luke corrected the approach or stated a durable preference.
- A loaded personal skill is materially wrong, incomplete, stale, or overly narrow.

Do not write a skill for a one-off result, transient status, speculation, or information the agent has not verified. Do not write down anything an agent could discover on its own from `--help`, man pages, official docs, or a quick look at the system (Luke, 2026-10-29). Keep only Luke's choices, decisions, and non-obvious gotchas. Create a new skill only when no existing Luke-authored skill is a natural home.

## Workflow

1. Inspect the loaded skill and its directly referenced files.
2. Identify the smallest reusable lesson and the evidence for it.
3. Patch `SKILL.md` for a short rule. Put detailed commands in one linked reference, and deterministic helpers in `scripts/`.
4. Apply the safety filter below.
5. Check frontmatter (`name`, `description`, `author: Luke`), relative links, and commands.
6. Run `python3 scripts/check-public-safety.py`. Treat any finding as blocking.
7. Review the diff, then commit and push.

## Size check

`scripts/check_skill_size.py` runs as part of the safety check. It fails any `skills/*/SKILL.md` over 200 lines and warns above 100. Move detail into linked `references/` rather than dropping a correct procedure. A simple skill should stay near 100 lines.

## Safety filter

- Never store passwords, tokens, private keys, session material, recovery data, or raw secret-manager identifiers.
- Do not add personal identifiers, private hostnames, IP addresses, emails, device IDs, or infrastructure topology unless the procedure needs that class of data and Luke has approved tracking it.
- Generalize examples where exact values are not required.
- Do not convert a single request into a permanent preference.
- Preserve explicit hard rules unless Luke changes them.
- If sensitivity or durability is unclear, ask Luke instead of writing.
- Put approved private operational values in the ignored `~/.agents/private-context.md`. The skill keeps placeholders and the procedure.

## Push with the GitHub PAT

On a machine with `gh` authenticated, use that. Without `gh`, push over HTTPS with the fine-grained PAT kept in Pass as an API Credential item (field `API Key`; item id in private context as `GH_PAT_ITEM`). The token stays out of config, argv, and output:

```bash
git -c credential.helper= -c credential.helper='!f(){ test "$1" = get || exit 0; echo username=x-access-token; printf "password=%s\n" "$(pass-cli item view --vault-name Main --item-id "$GH_PAT_ITEM" --field "API Key")"; }; f' push origin HEAD:main
```

Set `PROTON_PASS_AGENT_REASON` for that read. Follow `proton-pass-cli` for viewer-role and reason limits.

## Curation

If a skill's content is straightforward to discover on its own, drop the whole skill; if only a few gotchas or choices are not, trim it to those (Luke, 2026-10-29). Repair links and indexes that point at a dropped skill. Do not auto-delete a personal skill only because it looks unused. If two personal skills overlap, consolidate when the current task shows that is safe, and repair relative links.

## Self-maintenance

Update this skill when a verified change to discovery, portability, or this maintenance policy makes it wrong. Same evidence, safety, and push rules as above.
