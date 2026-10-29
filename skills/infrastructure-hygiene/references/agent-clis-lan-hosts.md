# Agent CLIs on LAN hosts (Proxmox, TrueNAS, PBS)

Use this when Luke wants the same Cursor Agent, Grok, Proton Pass, and personal-skill setup that already exists on the TrueNAS root home. Resolve SSH targets from `~/.agents/private-context.md`.

Luke treats the Proxmox nodes, TrueNAS, and the PBS VM as his machines. Stow **`common` then `personal`** there (`stow -t ~ common && stow -t ~ personal`). Do not stow `root/` onto these appliances. If `common` already owns `~/.bashrc.d` or `~/.config/hypr` as a whole-directory symlink, stowing `personal` folds those dirs so both packages can contribute. Keep host-local `zz-agent-tools.bash` in the folded `~/.bashrc.d`, never inside the checkout. Do not unstow a live desktop session to do this; that procedure is `native-desktop-temporary`.

## Shared pattern

1. Link only canonical guidance: `~/.agents` → the repo `common/.agents` tree.
2. Install Cursor Agent and Grok with their official installers. Keep `cursor-agent` as the Cursor binary name; Grok's installer may also create `agent`.
3. Install Proton Pass CLI as the official Linux binary and wrap it with `PROTON_PASS_KEY_PROVIDER=fs` plus a dedicated session directory.
4. Prefer a scoped viewer agent session over an owner login. An existing PAT session cannot create new agents; reuse a working scoped agent env file by copying it host-to-host without printing it.
5. Render `~/.agents/private-context.md` with `pass-cli inject` at mode 600. If an older CLI cannot resolve `pass://Main/...` share URLs, copy an already-rendered private-context file instead of leaving a failed inject.
6. Copy existing workstation `~/.config/cursor/auth.json` and `~/.grok/auth.json` at mode 600 when headless browser login is blocked. Verify with `cursor-agent status` and `grok models`. Codex uses `~/.codex/auth.json`, or `CODEX_HOME/auth.json` when `~/.codex` is a Stow link.

## Verified corrections (2026-08-23)

- A Pass session can say `Already authenticated` while `info` fails with `Error reading local key file` / `non-existent session`. `logout --force`, move the session dir aside, recreate it at mode `700`, then `login` from the copied `agent.env`.
- After the Grok installer prepends `~/.grok/bin` (so `agent` becomes Grok), append `PATH` again with `~/.local/bin` first. Keep `cursor-agent` as the Cursor binary name.
- If `~/.codex` is itself a Stow link, point `CODEX_HOME` outside the checkout and never write `auth.json` into the stowed tree. Check how the host installs CLIs (official installer, mise shims) before adding another copy.
- A replacement hypervisor may have no `git`. Official Cursor/Grok installers are enough; rsync `common/.agents` from the workstation if the GitHub clone is behind local skill edits.
- The Home Assistant Advanced SSH add-on is not an install target. Dropbear wedges if leftover SSH sessions stay `ESTABLISHED`, and copying a large CLI binary into `addon_configs` hangs.
- Reuse the same scoped viewer `agent.env` host-to-host. Do not create a new Pass agent from an existing PAT session.
- Sync the checkout with rsync and **exclude** `common/.config/Cursor/` (~1.9G workstation cache, not a tracked Stow input).
- TrueNAS disables `apt`. Keep the copied `stow`, `Stow.pm`, and `Stow/Util.pm` payload together under `~/.local/share/stow-perl`, then make `~/.local/bin/stow` a launcher that runs `perl -I"$HOME/.local/share/stow-perl" "$HOME/.local/share/stow-perl/stow" "$@"`. Do not rely only on `PERL5LIB`; non-interactive agent shells may not load it. Verify with `env -u PERL5LIB -u PERLLIB stow --version`.
- Before `stow common`, remove hand-made `~/.agents` / `~/.codex/AGENTS.md` links and real `~/.bashrc` files so Stow can fold. Keep host-local `~/.local/bin` CLI binaries as real files beside folded links. Put `private-context.md` in the checkout (`common/.agents/`, gitignored) so a folded `~/.agents` still has it.

## Proxmox hypervisor that already stows `common`

If `~/.local/bin`, `~/.bashrc`, `~/.cursor`, or `~/.config/systemd` are Stow links into the repo:

- Install binaries under a host-local prefix such as `~/.local/share/agent-tools/bin` and `~/.grok/bin`, not the stowed `~/.local/bin`.
- Put PATH/Pass env in the real `~/.profile` and a host-local `~/.bashrc.d/*.bash` file. Revert any installer edit to the stowed `.bashrc`.
- Do not write auth files or CLI config into the stowed `~/.cursor` tree. Use `~/.config/cursor/auth.json`.
- Use a system unit under `/etc/systemd/system` for Pass auto-login. A user unit under the stowed `~/.config/systemd` dirties the repo.

A clean Proxmox node without Stow can follow the NAS-style `$HOME/.local/bin` plus a user systemd oneshot.

## Codex updates when mise is already configured

Check `type -a codex`, `readlink -f "$(command -v codex)"`, `codex --version`, and `mise ls codex` before retrying an update. An older standalone installation earlier in PATH can hide a successful mise update. Use `mise upgrade codex` for an existing mise-managed installation. If a host-local `agent-tools/bin/codex` link shadows mise, back up that link and point it at `$HOME/.local/share/mise/shims/codex`; keep the launcher outside Stow. Verify from a fresh login shell with `codex --version`, `mise upgrade codex --dry-run`, `codex login status`, and `codex doctor --summary`. Keep binaries used by active sessions until those sessions exit; do not restart them merely to update the launcher.

## Home Assistant

The Advanced SSH add-on is Alpine/musl. Official Cursor, Grok, and Pass CLI builds are glibc and fail there even with `gcompat`. Do not disable protection mode to reach Docker. HAOS itself is not the install target: the OS root is appliance-managed. Install these CLIs on Proxmox, TrueNAS, and the PBS VM. A secondary Proxmox node that is offline is not a setup failure; retry when it is reachable.

The SSH add-on is intentionally left running for `/config` file work, but it is still not an install target. See `ha-ssh-addon-temporary-access.md`.
