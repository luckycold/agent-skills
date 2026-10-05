# Native hidden-workspace keyboard control

Verified on Hyprland 0.56.2 with a native Wayland Chromium browser. This uses
the user's existing browser process/profile, unlike T3's preview browser or a
nested desktop with its own profile. Do not put live addresses, account names,
screenshots, or monitor identifiers into the skill repository.

## Prepare and move

Inspect `hyprctl -j clients`, `hyprctl -j monitors`, and `hyprctl -j workspaces`.
Choose an unused workspace (11 is a suggestion, not a reserved number). Use a
dedicated browser window so the user's existing tabs remain where they are.
Browser `--new-window` is first-class, but creation may briefly show a window.
Launch-time workspace rules were not honored by a reused Chromium process in
the verification; do not promise invisible creation. Discover the newly created
window by comparing client lists before/after, not by guessing its address.

Modern Hyprland uses Lua dispatchers. Old `hyprctl dispatch focuswindow ...`
syntax failed on the tested version. Read installed `/usr/share/hypr/stubs/hl.meta.lua`
and current upstream documentation for the running version before adapting calls.

Use the discovered address in this table; examples below use `<window-address>`
as a descriptive placeholder that must be replaced at runtime:

```bash
hyprctl dispatch 'hl.dsp.window.move({window = "address:<window-address>", workspace = "11", follow = false})'
```

Verify the window's workspace and every monitor's `activeWorkspace`. Do not use
`wlrctl toplevel focus` for background operation: it activates the target.

## Make hidden captures fresh

Read the Omarchy capture and Hyprland references first. A hidden window can
accept input and update its title while its screenshot stays stale. Use a
temporary named rule scoped to the target class and unused workspace:

```bash
hyprctl eval 'desktop_agent_capture_rule = hl.window_rule({name = "temporary-agent-capture", match = {class = "^<browser-class>$", workspace = "11"}, render_unfocused = true})'
```

Escape the discovered class for a regex; choose a rule/global name that does not
overwrite existing work. This is runtime state, not a permanent config edit.
Record the rule handle so it can be disabled after use. Scope to a dedicated
workspace/class and do not accidentally affect the user's normal browser.
Verify the property with `hyprctl getprop address:<window-address> render_unfocused`.
Legacy `hyprctl setprop` returned `unknown request` on the tested version.

Get the target's `stableId` from `hyprctl -j clients`, then:

```bash
grim -T "$window_stable_id" -s 1 "$capture_path"
```

Inspect the image. Reloading and scrolling must produce fresh content; a title
change or a nonempty image alone is insufficient. Window captures may have
different dimensions from monitor captures; do not assume pointer coordinates
from a resized agent image match logical window coordinates.

## Target keyboard input

```bash
hyprctl dispatch 'hl.dsp.send_shortcut({mods = "CTRL", key = "l", window = "address:<window-address>"})'
hyprctl dispatch 'hl.dsp.send_shortcut({mods = "", key = "Escape", window = "address:<window-address>"})'
```

Every shortcut needs an explicit target. `mods = ""` sends an unmodified key.
ASCII letters and keysyms such as `period`, `slash`, and `Return` worked for URL
entry with a short delay between calls. `CTRL+r`, `CTRL+End`, and `CTRL+Home`
worked for reload and scrolling. Prefer a task's keyboard navigation where
practical; do not generalize this to arbitrary text or IME support.

Compare the active window address, visible workspace IDs, and cursor position
before/after a bounded operation. The compositor temporarily routes keyboard
events to the selected surface and restores keyboard focus; this is not a
separate input seat. Stop if focus/workspaces change unexpectedly. Coordinate
with the user when physical modifiers, typing, or app behavior cause contention.

## Finish

Disable the rule using its recorded handle:

```bash
hyprctl eval 'desktop_agent_capture_rule:set_enabled(false)'
```

Close only agent-created test windows, using the version's address-targeted
window-close dispatcher, unless the user wants to retain a dedicated background
window. Do not close the browser process or unrelated tabs. Retained runtime
rules disappear on configuration reload; recheck them before future capture.
