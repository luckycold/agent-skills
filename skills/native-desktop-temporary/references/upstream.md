# Replacement integration: recheck before adopting

Research checkpoint: 2026-10-05. These are upstream sources, not a promise of
installed support or a release schedule.

- [Cua's Omarchy collaboration](https://github.com/trycua/cua/blob/main/blog/omarchy-cua-driver.md),
  published September 25, 2026: Cua Driver plus a Hyprland plugin provides a
  compositor-native synthetic cursor and isolated agent input. Available in
  Omarchy Edge; stable promotion was not verified in the announcement.
- [Platform support](https://cua.ai/docs/cua-driver/concepts/platform-support):
  consult its current qualification matrix. At this checkpoint Hyprland was
  experimental, with a narrow Calc/Inkscape qualification and explicit limits
  for Chromium/Electron/XWayland raw input, Unicode/IME, and keyboard layouts.
  The plugin must match the running Hyprland ABI and toolchain.
- [Omarchy VM guide](https://cua.ai/docs/cua-sdk/guides/omarchy): describes the
  Edge image with `cua-driver-bin` and `cua-hyprland-plugin`, two agent seats,
  a user service, and MCP tools. A VM demonstration does not prove native
  installed-host support.
- [Omarchy Agent Desktops proposal](https://github.com/omacom/omarchy/pull/10594):
  separate background Hyprland desktops, viewer, and MCP controls.
  Still open at this checkpoint; no confirmed shipping date. Its separate
  browser profiles differ from operating an existing signed-in native browser.
- [omabox](https://github.com/diogochaves/omabox): community project with nested
  headless Hyprland instances and separate desktop/session state. This is a
  separate architecture, not a transparent continuation of the user's windows.

Check `command -v cua-driver`, `cua-driver --version`, package metadata, and
`hyprctl plugin list` separately. A driver executable alone does not prove the
Hyprland plugin is loaded or background input is supported. No stable-release
ETA was established by the sources above. Prefer supported package paths and
route any MCP configuration through the user's canonical mcporter registry.

## Diagnose a compositor update before reinstalling

Inspect `pacman -Si cua-hyprland-plugin`, `hyprctl version`, and
`hyprctl plugin list` independently. A removed plugin can leave a healthy
`cua-driver-bin` package and daemon; reinstalling the driver does not repair
an incompatible plugin. Never bypass the plugin's exact compositor/library
dependencies or assume that a newer driver supplies a compatible plugin.

An empty `list_windows` result also needs comparison with `hyprctl -j clients`.
On Hyprland 0.57.0, an unused special workspace can omit its `id`, breaking
Driver's monitor-reply parser ([upstream issue #6267](https://github.com/trycua/cua/issues/6267)).
Desktop capture can still succeed. Check the current status of that fix and
[plugin input support #6232](https://github.com/trycua/cua/issues/6232)
separately before selecting an update. A successful screenshot does not prove
window discovery or isolated input. Preserve the working desktop and ask
before a graphics-stack rollback or an unreleased local patch/build.

When the user chooses a different Omarchy channel, use
`omarchy channel set <channel>`: it performs a downgrade-capable whole-system
sync and swaps the Omarchy package pair. Inspect that channel's actual package
database first, then reinstall its matching plugin through pacman. Run the
packaged `profile_verify.py --consumer` check with `--kit` pointing to the
provenance directory and `--kit-sha256` set to its `KIT-PROVENANCE.json` hash.
This proves installed compatibility, not live activation; a replaced running
Hyprland process still needs a session restart or reboot.

For a service-launched shell without display variables, compare
`systemctl --user show-environment` with the existing daemon's environment
before changing its unit. Run diagnostics with the graphical session's
selected display variables; a headless caller's warning alone does not prove
that the desktop daemon lacks them. Do not print unrelated environment values.
