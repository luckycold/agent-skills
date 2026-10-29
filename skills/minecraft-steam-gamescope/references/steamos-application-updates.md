# SteamOS application updates through Decky

## Choose the supported updater

- Inspect the OS, installed Decky plugins, Flatpak installation scopes, and
  `flatpak run it.mijorus.gearlever --list-installed` before changing anything.
- Discover can already have `UseUnattendedUpdates=true` in
  `~/.config/PlasmaDiscoverUpdates`. Its notifier is KDE-only; that setting
  does not establish automatic updates in Gaming Mode.
- [Apps Manager](https://github.com/moi952/decky-apps-manager) is a Decky plugin
  covering both system/user Flatpaks, pending runtimes, and Gear Lever-managed
  AppImages. Its backend performs periodic checks without opening the panel.
- Gear Lever's background-fetch option alone checks and notifies; it does not
  schedule unattended installation. Apps Manager supplies that scheduling.
- AppImages must be registered in Gear Lever and have a working update source.
  Keep EmuDeck-managed AppImages on EmuDeck's updater unless explicitly migrating
  their ownership. Do not claim every AppImage on disk is covered.

## Install and configure

Use the upstream release ZIP and Decky's normal installer. Verify the ZIP's
SHA-256 against the release asset's published digest before installation. Do not
patch Decky or the plugin, manually copy files into the root-owned plugins
directory, or add another scheduler around the plugin.

For an authorized CLI installation, Decky's existing loopback API can perform
the same install workflow without a sudo password:

1. Inspect upstream source for the **installed Decky version**, especially
   `wsrouter.py`, `utilities.py`, `browser.py`, and `loader.py`.
2. Fetch `/auth/token` into memory and connect to `/ws` with its auth parameter.
   Never print, persist, or commit the token or authenticated URL. A new socket
   replaces Decky's existing frontend socket; avoid interfering with an active
   plugin operation and close the agent connection afterward.
3. Call `utilities/install_plugin` with the verified local `file://` ZIP,
   plugin name, version, SHA-256, and install type. Capture the
   `loader/add_plugin_install_prompt` event and confirm its request identifier
   through `utilities/confirm_plugin_install` after user authorization.
4. Verify `loader/get_plugins` reports Apps Manager enabled. Through
   `loader/call_plugin_method`, set `set_update_check_interval_minutes(180)`,
   `set_auto_update_interval_minutes(1440)`, and
   `set_auto_update_enabled(true)` for three-hour checks and daily installations.
   Read back all three corresponding getters.

Decky 3.2.6 uses message types CALL=0, REPLY=1, EVENT=3, ERROR=-1, with positional
arguments in `args`. It does **not** support the newer response-ack protocol;
using master-branch protocol assumptions causes unknown-message errors.

## Verify and explain limits

- Settings persist under Decky's `settings/decky-apps-manager/` directory as
  `auto_update.json`, `auto_update_interval.json`, and
  `update_check_interval.json`. Prefer plugin setters over guessing file formats.
- Allow the initial scan to finish before requesting another forced scan:
  Flatpak commit-mismatch checks can run `flatpak update --no-deploy`, downloading
  update content during the check. Concurrent forced scans duplicate that work.
- Check the plugin's live app list or persisted `apps_cache.json`, Decky service
  logs, and auto-update history. Verify both installation scopes and the expected
  AppImages; a saved enabled flag alone does not prove a successful update run.
- Gear Lever updates use `--update <path> --yes` without `--force`, so running
  AppImages are skipped. Do not equate a successful CLI exit or batch history
  entry with proof that a skipped application's version changed.
- The machine must be awake and online; scheduling does not wake it from suspend.
  Users can inspect settings and update history in Gaming Mode under
  Decky → Apps Manager.
