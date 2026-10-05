---
name: native-desktop-temporary
description: Temporary native Wayland desktop and browser control from a CLI agent on Omarchy. Distinguish the user's actual desktop from T3 Code's collaborative preview browser; inspect screenshots and operate existing desktop utilities.
author: Luke
---

# Temporary native desktop control

This is an interim workflow while staying on Omarchy stable. On each invocation,
check `omarchy version` and `omarchy channel current`, then consult current
official release notes and [upstream integration](references/upstream.md) to see
whether normal computer use is available for the installed stable release.
An announcement or Edge-only feature does not establish stable availability.

When supported integration becomes available, migrate to its maintained install
and normal tool workflow. Verify native browser access, background input and
capture without disturbing the user's focus, and compatibility with the running
compositor before retiring the workaround. Remove only this workflow's temporary
rules and resources after successful replacement. The user authorizes deletion
of this skill once that migration is verified: remove the entire
`native-desktop-temporary` package from the canonical skill repository, publish
through `personal-skill-maintenance`, and remove its installed copies and
compatibility links so agents no longer discover it. Do not delete it merely
because support is announced or a partial replacement exists.

## Choose the correct surface

- T3 Code `preview_*` tools operate its collaborative browser, with its own
  tabs and authentication state. They do not operate the user's native browser
  or prove that the user is signed out there.
- For an explicit request to use the native browser or desktop, use the local
  machine's existing tools when the session permits them. A disabled native API
  in one browser integration does not by itself establish that shell-based
  desktop automation is unavailable. Respect actual session restrictions.
- For T3 preview work, use its tools and normal status/open/snapshot workflow.
  Do not silently substitute a different browser or profile.
- Native tools need access to the running Wayland session. SSH or another host's
  shell alone does not establish desktop access.

## Verified foreground workflow

Load the Omarchy skill and its capture reference before desktop capture or
window-management work. Discover binaries and current state first:

```bash
command -v wlrctl wtype grim hyprctl
hyprctl -j clients
hyprctl -j monitors
hyprctl -j activewindow
```

Select the native browser's actual app ID from the client list; do not infer it
from the executable's name. Focus it, then verify the active window before input:

```bash
wlrctl toplevel focus "app_id:$browser_app_id"
hyprctl -j activewindow
```

`wlrctl` window focusing succeeded in the verified workflow, but its rapid
keyboard input lost characters. Use the installed `wtype` for paced typing and
explicit keys. Open a new tab, allowing the browser to process the shortcut
before sending text:

```bash
wtype -M ctrl -k t -m ctrl
sleep 0.3
wtype -d 60 "$target_url"
wtype -k Return
```

For an existing tab, use Ctrl+L instead of Ctrl+T. Inspect a fresh screenshot to
confirm the destination and account identity; command success alone is not
proof of navigation. Never type into an unverified focused window.

```bash
grim -o "$output_name" -s 1 "$capture_path"
```

Open the resulting image through the agent's image-viewing tool. Obtain output
names dynamically. With `-s 1`, screenshot pixels correspond to logical output
coordinates; pointer coordinates also require that output's global offset.
Keep screenshots local and temporary; exclude account details and screenshots
from the public skill library.

## Background control

Prefer the verified hidden-workspace workflow when the user asks to keep work
out of view. Read [background control](references/background.md) before using it.
On Hyprland 0.56.2, address-targeted `hl.dsp.send_shortcut`, a silent move to an
inactive workspace, and `grim -T` with a scoped `render_unfocused` rule worked
for a native Wayland Chromium browser. Navigation, reload, scrolling, and fresh
capture succeeded without switching visible workspaces or leaving the target
focused. A short targeted-shortcut test also preserved physical cursor position.

This verifies keyboard-driven background browsing, not generic background mouse
input. `wtype` and `wlrctl` virtual keyboard/pointer target session input; do not
use them to type or click into a hidden window. Do not focus an invisible window
as a substitute for targeted input. App dialogs, Unicode/IME, other toolkits,
and arbitrary mouse actions require separate verification.

For replacement research, consult [upstream integration](references/upstream.md).
Recheck current support, installed versions, and loaded plugins before choosing
the newer route. Do not install a compositor plugin merely because this skill
exists.

## Self-maintenance

Follow `personal-skill-maintenance` for verified corrections and publication.
Keep this temporary, portable, and free of live identifiers. Recheck upstream
support before adding wrappers, services, or a permanent desktop architecture.
