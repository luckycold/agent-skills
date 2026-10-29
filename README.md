# Luke's Agent Skills

Luke-authored portable skills for infrastructure, authentication, and agent workflow maintenance. This is a **public** repository: procedures use placeholders, while private operational values remain in an ignored local `~/.agents/private-context.md`.

Consumers include Labby (Cursor home-lab bot), Codex, Cursor, Claude Code, OpenCode, and Grok Bot. Prefer portable skills over agent-specific paths.

## Install

Install or refresh with skills.sh, the Agent Skills CLI (Codex, Claude Code, Cursor, OpenCode). On hosts with Luke's dotfiles, `update-agent-skills` wraps this:

```bash
DISABLE_TELEMETRY=1 npx --yes skills@latest add luckycold/agent-skills \
  --skill '*' --global --yes \
  --agent codex --agent claude-code --agent cursor --agent opencode
```

The canonical agent working agreement is `~/.agents/AGENTS.md` from Luke's dotfiles, not this repository; `AGENTS.md` here is only a repository note. Do not clone this repository over `~/.agents` on a host that stows the dotfiles.

Generic Proton Pass CLI instructions are not stored here. `pass-cli agent instructions` prints them. Luke-specific limits stay in `proton-pass-cli`.

## Skills

- `direct-action-preferences` — package source order, AUR review, Omarchy TPM/PCR 7, ask before custom glue
- `infrastructure-hygiene` — UniFi, Traefik/Authelia lockdown, TrueNAS DNS and storage, qbit_manage, RomM, HA SSH add-on
- `minecraft-steam-gamescope`
- `native-desktop-temporary`
- `ntfy-ops`
- `personal-skill-maintenance`
- `proton-pass-cli` — Luke-specific Pass CLI facts; generic usage comes from `pass-cli agent instructions`
- `proxmox-homelab`
- `steam-frame-linux-networking`
- `steam-hyprland-scaling`
- `truenas-custom-apps`
- `uptime-kuma`

## Safety and validation

Before committing:

```bash
python3 scripts/check-public-safety.py
DISABLE_TELEMETRY=1 npx --yes skills@latest add . --list
```

The repository's safety check rejects common secret formats, private keys, private network addresses, private-domain markers, emails, and tracked private-context files. It also runs `scripts/check_skill_size.py`, which fails any `skills/*/SKILL.md` over 200 lines and warns above 100. GitHub Actions runs the same check on pushes and pull requests.
