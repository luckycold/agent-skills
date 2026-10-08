# Luke's Agent Skills

Luke-authored portable skills for infrastructure, automation, authentication, and agent workflow maintenance. This is a **public** repository: procedures use placeholders, while private operational values remain in an ignored local `~/.agents/private-context.md`.

First-class consumers include Labby (Cursor home-lab bot), Codex, Cursor, Claude Code, OpenCode, OpenClaw, and Hermes (historical Home Assistant add-on agent). Prefer portable skills; Hermes-specific HA-addon paths stay in `infrastructure-hygiene` references.

## Canonical checkout

Clone this repository as the shared cross-agent skills area:

```bash
git clone https://github.com/luckycold/agent-skills.git ~/.agents
```

Install or refresh with the Agent Skills CLI (Codex, Claude Code, Cursor, OpenCode):

```bash
DISABLE_TELEMETRY=1 npx --yes skills@latest add luckycold/agent-skills \
  --skill '*' --global --yes \
  --agent codex --agent claude-code --agent cursor --agent opencode
```

Hermes (historical HA add-on) can also load the checkout as an external directory:

```bash
hermes config set skills.external_dirs '["~/.agents/skills"]'
hermes skills tap add luckycold/agent-skills
```

`skills.external_dirs` makes the checked-out packages available to Hermes and writable in place. The tap adds the GitHub repository as a discovery/install source; it does not replace the writable checkout.

## Skills

- `direct-action-preferences`
- `infrastructure-hygiene`
- `minecraft-steam-gamescope`
- `native-desktop-temporary`
- `ntfy-ops`
- `personal-skill-maintenance`
- `proton-pass-cli`
- `proxmox-homelab`
- `steam-frame-linux-networking`
- `steam-hyprland-scaling`
- `tasker-automation`
- `temporary-support-watcher-cleanup`
- `truenas-custom-apps`

## Safety and validation

Before committing:

```bash
python3 scripts/check-public-safety.py
DISABLE_TELEMETRY=1 npx --yes skills@latest add . --list
```

The repository's safety check rejects common secret formats, private keys, private network addresses, private-domain markers, emails, and tracked private-context files. It also runs `scripts/check_skill_size.py`, which fails any `skills/*/SKILL.md` over 200 lines and warns above 100. GitHub Actions runs the same check on pushes and pull requests.
