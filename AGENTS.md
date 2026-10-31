# agent-skills repository note

This is Luke's public library of portable Agent Skills (`skills/<name>/SKILL.md`, frontmatter `author: Luke`). It holds only the knowledge an agent could not work out on its own: Luke's choices, decisions, and non-obvious gotchas. Drop or trim anything that `--help`, man pages, official docs, or a quick look at the system would tell an agent.

- **Install and refresh:** skills.sh, for example `npx skills add luckycold/agent-skills --skill '*' --global --yes`. See `README.md`.
- **Agent rules:** the canonical working agreement is `~/.agents/AGENTS.md`, stowed from Luke's dotfiles repository (`common/.agents/AGENTS.md`). This file is only a note about this repository; it does not override that agreement.
- **Maintenance:** follow the `personal-skill-maintenance` skill.
- **Before every commit:** run `python3 scripts/check-public-safety.py`. It rejects secrets, private keys, private network addresses, private domains, emails, and tracked private-context files, and it runs `scripts/check_skill_size.py`, which fails any `skills/*/SKILL.md` over 200 lines. A failure blocks the commit; generalize the content instead of weakening the check.
- **Public repository:** use placeholders such as `<nas-ssh-target>`; exact values belong in the ignored local `~/.agents/private-context.md`, which is never committed or quoted.
