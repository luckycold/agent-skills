# Luke's Agent Working Agreement

This repository is the canonical, public, cross-agent library for Luke-authored skills. Project-specific instructions take precedence when they conflict.

## Core preferences

- Prefer functional programming where practical: pure functions, immutability, composition, and explicit data flow.
- Satisfy the type checker. Ask Luke before choosing a complicated, brittle workaround.
- Follow each repository's existing style and architecture. Do not refactor unrelated code.
- Inspect current state before acting. Ask only when required information is external, destructive, sensitive, or depends on a material user choice.
- Prefer supported first-class configuration over custom wrappers or bespoke glue unless Luke explicitly requests that implementation.

## Skill freshness

At the start of each new run — once per session, not every turn — refresh installed portable skills with the skills.sh CLI before other work.

Non-interactive shells do not load Luke's bash functions. In the same command:

```bash
source "${DOTFILES_DIR:-$HOME/dotfiles}/common/.bashrc.d/dotfiles_management.bash"
update-agent-skills
```

That is the skills.sh (`skills`) CLI: `add luckycold/agent-skills --skill '*' --global --yes` for Codex, Claude Code, Cursor, and OpenCode. If this session already ran it, skip. If Node.js or npm is missing, report that and continue with on-disk skills. After a refresh that changed files, re-read `~/.agents/AGENTS.md` and the skills this task needs.

## Personal skills

Luke-authored personal skills are canonical under `~/.agents/skills/` and have top-level `author: Luke` frontmatter.

- Keep each skill under `skills/<skill-name>/` with a valid `SKILL.md` entrypoint.
- Keep `SKILL.md` focused: target about 100 lines for a simple skill and 200 lines for a complex skill, matching Hermes' default authoring guidance. If it grows beyond that, move detailed procedures, examples, and historical notes into directly linked `references/`; put deterministic helpers in `scripts/`. Do not shorten at the expense of correctness, but treat an oversized `SKILL.md` as something to refactor before committing.
- Load the relevant personal skill before acting on Luke's infrastructure, authentication, automation, or agent-maintenance work.
- Use `personal-skill-maintenance` when creating, correcting, consolidating, or extending personal skills.
- Never self-modify third-party, bundled, system, or project-owned skills.

## Private context and public-repository safety

This repository is public. It must contain portable procedures, not Luke's live environment values.

- Never commit passwords, tokens, private keys, session material, recovery data, secret-manager IDs, auth files, callback payloads, or rendered private context.
- Never commit private hostnames, private domains, RFC1918 addresses, emails, MAC/device IDs, account aliases, or detailed live infrastructure topology.
- Use descriptive placeholders such as `<nas-ssh-target>` or environment variables such as `${NAS_IP}` when exact values are required at runtime.
- Resolve approved private operational values from the local, ignored `~/.agents/private-context.md` only when a task needs them. Never quote, commit, log, or copy that file.
- Keep `private-context.md`, `private-context.template.md`, exports, logs, archives, and credential material ignored.
- Run `python3 scripts/check-public-safety.py` before every commit. Treat a failure as blocking; fix or deliberately generalize the content rather than weakening the check.

## Self-learning and Git

- Update a personal skill when a verified reusable correction, user correction, or repeatable workflow would improve future runs.
- Create a new skill only for a non-trivial workflow likely to recur and only when no existing skill is a natural home.
- Make the smallest evidence-backed edit. Do not store transient state or infer a durable preference from one request.
- Review the full diff and validate every changed skill before committing.
- Luke has authorized this agent to commit and push safe personal-skill updates to `luckycold/agent-skills` without asking each time.
- Never push when the safety scan or validation fails. Do not rewrite published history unless Luke explicitly authorizes it for incident response.
- Always state in the user-facing final response when a skill was created or updated. Name every changed skill and include the resulting pushed commit; never leave a skill change implicit.
