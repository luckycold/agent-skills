# Luke's Agent Skills

Luke-authored skills for infrastructure, automation, authentication, and agent workflow maintenance. Each skill follows the portable Agent Skills format and can be installed for supported coding agents with the [`skills`](https://github.com/vercel-labs/skills) CLI.

## Install

```bash
DISABLE_TELEMETRY=1 npx --yes skills@latest add luckycold/agent-skills \
  --skill '*' --global --yes \
  --agent codex --agent claude-code --agent cursor --agent opencode
```

Run the same command again to refresh the collection and discover newly added skills.

## Skills

- `direct-action-preferences`
- `infrastructure-hygiene`
- `personal-skill-maintenance`
- `proton-pass-cli`
- `tasker-automation`
- `truenas-custom-apps`
