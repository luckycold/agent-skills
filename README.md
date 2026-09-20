# Luke's Agent Skills

Luke-authored portable skills for infrastructure, automation, authentication, and agent workflow maintenance. This is a **public** repository: procedures use placeholders, while private operational values remain in an ignored local `~/.agents/private-context.md`.

## Canonical checkout

Clone this repository as the shared cross-agent skills area:

```bash
git clone https://github.com/luckycold/agent-skills.git ~/.agents
```

Hermes supports external skill directories directly. Configure the checkout as an active source:

```bash
hermes config set skills.external_dirs '["~/.agents/skills"]'
hermes skills tap add luckycold/agent-skills
```

`skills.external_dirs` makes the checked-out packages available to Hermes and writable in place. The tap adds the GitHub repository as a discovery/install source; it does not replace the writable checkout.

For other compatible coding agents, install or refresh with the Agent Skills CLI:

```bash
DISABLE_TELEMETRY=1 npx --yes skills@latest add luckycold/agent-skills \
  --skill '*' --global --yes \
  --agent codex --agent claude-code --agent cursor --agent opencode
```

## Skills

- `direct-action-preferences`
- `infrastructure-hygiene`
- `personal-skill-maintenance`
- `proton-pass-cli`
- `steam-hyprland-scaling`
- `tasker-automation`
- `truenas-custom-apps`

## Safety and validation

Before committing:

```bash
python3 scripts/check-public-safety.py
DISABLE_TELEMETRY=1 npx --yes skills@latest add . --list
```

The repository's safety check rejects common secret formats, private keys, private network addresses, private-domain markers, emails, and tracked private-context files. GitHub Actions runs the same check on pushes and pull requests.
