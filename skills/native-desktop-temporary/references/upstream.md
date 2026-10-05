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
  separate background Hyprland desktops, viewer, MCP controls, and optional T3
  chat. Still open at this checkpoint; no confirmed shipping date. Its separate
  browser profiles differ from operating an existing signed-in native browser.
- [omabox](https://github.com/diogochaves/omabox): community project with nested
  headless Hyprland instances and separate desktop/session state. This is a
  separate architecture, not a transparent continuation of the user's windows.

Check `command -v cua-driver`, `cua-driver --version`, package metadata, and
`hyprctl plugin list` separately. A driver executable alone does not prove the
Hyprland plugin is loaded or background input is supported. No stable-release
ETA was established by the sources above. Prefer supported package paths and
route any MCP configuration through the user's canonical mcporter registry.
