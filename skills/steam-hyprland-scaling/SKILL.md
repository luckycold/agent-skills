---
name: steam-hyprland-scaling
description: >
  Steam client UI scale on Hyprland/Omarchy. The CEF scale restarter was
  removed. Triggers: Steam too small or too big, GDK_SCALE, steam-launch,
  --force-device-scale-factor, steamwebhelper SIGTRAP, g_pipe_pid.
author: Luke
---

# Steam on Hyprland

The CEF scale helper was removed from the dotfiles. Do not bring it back.

`steam-launch --sync` patched `--force-device-scale-factor` into Steam's
webhelper wrapper and sent SIGTERM to every process whose argv[0] was
`./steamwebhelper`. On the SteamRT3 client (`steamrt64/steamwebhelper.sh`)
a child between fork and exec still has that argv[0]. SIGTERM in that window
runs CEF's inherited shutdown handler and aborts with
`Check failed: g_pipe_pid == getpid()` (SIGTRAP). The restart loop produced
hundreds of `steamwebhelper` core dumps.

The remaining `steam-launch` wrapper, user desktop-entry overrides, autostart,
and `hypr/steam.lua` window rules were also removed. Launch Steam with the
package-provided `steam.desktop`; use Steam's Accessibility UI Scale slider.
There is no custom environment cleanup or libextest preload in the launcher.

When removing a Stow-managed launcher, remove its deployed symlinks as well
as the tracked files so no dangling user desktop entry shadows the package.
Refresh the user desktop database and verify that `steam.desktop` resolves
to the package-provided file. Validate Hyprland after removing Lua requires.

## Dead ends

- Do not SIGTERM `steamwebhelper`, or any argv[0] match, to apply scale.
- Do not patch `steamwebhelper.sh` or `steamwebhelper_sniper_wrap.sh`.
- Do not set a global `GDK_SCALE` / `GDK_DPI_SCALE`. That integer cannot be
  right on mixed-DPI, and Omarchy's monitor-scaling keybind persists it onto
  every GTK/X11 app.
- Do not trust `-forcedesktopscaling` or `STEAM_FORCE_DESKTOPUI_SCALING`.
  Valve removed them when the Accessibility UI Scale slider landed.
- Do not expect `config.vdf` `UI.display.Current.ScaleFactor` to persist.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical
package under `~/.agents/skills/` when a verified reusable correction, user
correction, or repeatable workflow would improve future runs. Make the
smallest evidence-backed edit, do not record secrets or transient state, and
do not infer a durable preference from one request. Follow the
`personal-skill-maintenance` skill for the full review and verification
workflow.
