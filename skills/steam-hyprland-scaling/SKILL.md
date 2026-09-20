---
name: steam-hyprland-scaling
description: >
  Fix Steam client UI scale on Hyprland/Omarchy mixed-DPI, especially when
  the store URL bar is tiny next to the desktop bar. Triggers: Steam too
  small or too big, GDK_SCALE, -forcedesktopscaling, STEAM_FORCE_DESKTOPUI_SCALING,
  XWayland force_zero_scaling, Accessibility UI Scale, steam-launch, CEF
  --force-device-scale-factor, SteamRT3 experimental client.
author: Luke
---

# Steam HiDPI on Hyprland

Steam's desktop UI is XWayland CEF. On Hyprland with `xwayland.force_zero_scaling`,
it paints physical pixels and must self-scale. Current Steam public beta does
not honor the old launch flags.

## What actually sizes the chrome

Compare Steam's URL bar / `STORE` / `LIBRARY` text to the compositor bar
(clock, media widget). Window-relative density is misleading: the same 2x UI
looks oversized in Omarchy's 1100x700 Steam box and tiny in a ~90% monitor
window.

The working control is Chromium's `--force-device-scale-factor`, set to the
Hyprland monitor scale the Steam window occupies (2 on a 2x laptop, 1.5 on a
1.5x 4K panel, 1 on a 1x 1440p). The personal `steam-launch` wrapper injects
that flag into `ubuntu12_64/steamwebhelper_sniper_wrap.sh` and re-applies it
after Steam's "Verifying installation" restores the stock script. If CEF
starts without the flag, bounce only `./steamwebhelper`, not the wrap/bwrap
processes.

## Dead ends

- Do not set a global `GDK_SCALE` / `GDK_DPI_SCALE`. That integer cannot be
  right on mixed-DPI, and Omarchy's monitor-scaling keybind persists it onto
  every GTK/X11 app.
- Do not trust `-forcedesktopscaling` or `STEAM_FORCE_DESKTOPUI_SCALING`.
  Valve removed them when the Accessibility UI Scale slider landed.
- Do not expect `config.vdf` `UI.display.Current.ScaleFactor` to persist.
  Steam rewrites that block on startup and often keeps the last docked
  1440p `AutoScaleFactor` (~0.95), which is why HiDPI chrome stays tiny.
- Desktop file overrides should only change `Exec=` to `steam-launch`. They
  are not a scale mechanism.
- SteamRT3 ("experimental SteamRT3 Steam Client") is a 64-bit containerized
  client, not native Wayland. It will not fix scale by itself and may move
  the wrap path.

## Launch and resync

Launch through `steam-launch`. `--sync` restarts the client when the window
lands on a different monitor scale. Do not restart while `steam_app_*` game
windows exist. After Hyprland Lua timer debounce, disable the previous timer
with `set_enabled(false)` — `cancel()` is not a method on 0.56 `hl.timer`.

Keep a large Steam window (monitor-relative). The 1100x700 Omarchy default is
a 1x-era size and makes any correct scale look cramped.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical
package under `~/.agents/skills/` when a verified reusable correction, user
correction, or repeatable workflow would improve future runs. Make the
smallest evidence-backed edit, do not record secrets or transient state, and
do not infer a durable preference from one request. Follow the
`personal-skill-maintenance` skill for the full review and verification
workflow.
