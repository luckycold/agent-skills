---
name: minecraft-steam-gamescope
description: Diagnose Minecraft Java low FPS under Steam Gaming Mode and configure a windowed PolyMC instance to follow Steam's virtual display resolution. Use for Gamescope fullscreen retry loops and dynamic window sizing, not Steam client UI scaling.
author: Luke
---

# Minecraft through Steam and Gamescope

Inspect the actual Steam shortcut, launcher instance, renderer logs, and running processes before changing settings. Preserve existing mods, accounts, launch arguments, and server selection.

## Fullscreen retry diagnosis

- Confirm the renderer from Minecraft's `latest.log`; enumerating graphics adapters does not prove which one renders the game.
- Repeated `Exclusive target` and `Failed to synchronize SDL window` messages around nine or ten times per second can identify a fullscreen retry loop. SDL's X11 window-sync path normally allows about 100 ms per pending operation, matching roughly 10 FPS when retried every frame.
- Test ordinary windowed mode with `fullscreen:false` and `exclusiveFullscreen:false`. Native borderless mode still invokes SDL fullscreen operations on Linux and is not guaranteed to fix this failure. If the user verifies that only fully windowed mode works, preserve that result.
- The SDL error text about an environment variable can be stale; do not infer which environment variable caused the failure from that text alone.
- Do not confuse Gamescope scaling a small window to fill the screen with Minecraft rendering at the screen's resolution.

## Follow Steam's resolution without Minecraft fullscreen

Steam's per-game **Game Resolution: Native** controls the virtual display exposed to the game. It does not necessarily resize a game window. Use the existing Steam UI or native `SteamClient.Apps.SetAppResolutionOverride(appid, 'Native')` API where available; verify the resulting setting. Do not patch Steam's JavaScript or restart Steam solely to edit a setting if the native API is accessible.

Gamescope does not provide a supported per-game width/height environment-variable pair. Query the virtual X display addressed by the launched process's `$DISPLAY`, rather than a physical monitor or a hardcoded display number. In Gaming Mode, `xrandr --current` reports Steam's virtual screen. In a desktop session, its root dimensions can span multiple monitors; this one-liner is intended for Steam Gaming Mode or a single-monitor desktop.

PolyMC's numeric window-size fields do not expand environment variables. Minecraft's `overrideWidth` and `overrideHeight` values in `options.txt` take precedence over the launcher's width/height arguments. Updating those two options immediately before Minecraft starts is sufficient.

Before adding a custom hook, follow `direct-action-preferences` and obtain the package-versus-custom-hook choice unless the user already authorized a simple hook. Check for an existing instance pre-launch command and preserve it. Check whether the PolyMC Flatpak already includes `xrandr`, `awk`, `sed`, and `/usr/bin/sh`; the verified Flatpak did, so no helper package was needed.

PolyMC runs its pre-launch command with the Minecraft game directory as the working directory. After backing up `instance.cfg`, enable `OverrideCommands=true` and set this single-line command in the instance's Custom Commands UI:

```text
/usr/bin/sh -c "set -- $(xrandr --current | awk 'NR==1 {print $8,int($10)}'); [ $# -eq 2 ] && sed -i -e s/^overrideWidth:.*/overrideWidth:$1/ -e s/^overrideHeight:.*/overrideHeight:$2/ options.txt"
```

It recalculates dimensions at every launch. It does not resize a running game after changing displays. If the display query fails, the guard prevents writing invalid dimensions and the pre-launch step can fail visibly; inspect the launcher log rather than silently inventing a resolution.

### Direct instance.cfg editing

PolyMC uses its own `INIFile` parser, not QSettings. Quotes remain literal. Escape backslashes as `\\` and hashes as `\#`; do not wrap the entire value in extra quotes or escape its ordinary double quotes. An unescaped `#` in `$#` is treated as an INI comment and truncates the command.

The correctly serialized line is:

```ini
PreLaunchCommand=/usr/bin/sh -c "set -- $(xrandr --current | awk 'NR==1 {print $8,int($10)}'); [ $\# -eq 2 ] && sed -i -e s/^overrideWidth:.*/overrideWidth:$1/ -e s/^overrideHeight:.*/overrideHeight:$2/ options.txt"
```

Edit only while the launcher and game are stopped; use a backup and atomic replacement. Enabling the instance command override also selects the instance's wrapper and post-exit commands, so inspect those and any global commands first.

## Verification

Exercise the shell command inside the existing Flatpak on a temporary copy of `options.txt`. Then check one actual Steam launch to catch PolyMC's parsing and environment behavior: the launcher log must show `PreLaunchCommand` succeeded, options must contain positive detected dimensions, and fullscreen must remain false. Check for continuing fullscreen retries. Distinguish a successful desktop launch from a Gaming Mode performance or alternate-resolution check; report only what was observed.

## Sources

- [Gamescope virtual display and sizing](https://github.com/ValveSoftware/gamescope)
- [SDL X11 synchronization timeout](https://github.com/libsdl-org/SDL/blob/main/src/video/x11/SDL_x11window.c)
- [PolyMC pre-launch argument parsing](https://github.com/PolyMC/PolyMC/blob/develop/launcher/launch/steps/PreLaunchCommand.cpp)
- [PolyMC INI escaping](https://github.com/PolyMC/PolyMC/blob/develop/launcher/settings/INIFile.cpp)

## Self-maintenance

This is a Luke-authored personal skill. Update it only with verified reusable corrections, following `personal-skill-maintenance`; keep live host, account, instance, and server values out of the public library.
