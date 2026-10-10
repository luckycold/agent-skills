# Cua with a dedicated Brave profile on Omarchy

Recheck the installed image, compositor/plugin ABI and current Cua documentation.
Omarchy support is experimental. A successful screenshot does not establish raw
input reliability for Chromium; prefer an exactly bound browser capability.

For a user-authorized dedicated desktop, launch the packaged Brave executable
with a separate persistent user-data directory and a loopback-only DevTools port.
Do not copy, restart or enable debugging on an unrelated existing user profile.
The Arch package executable can be `/opt/brave-bin/brave`; resolve the installed
package rather than assuming a `brave-browser` command exists.

Use the packaged Cua user service. A host-local override may add the native
`serve --grant existing-profile` flag when the user has explicitly authorized
attachment. Preserve standard permission mode. Do not use unrestricted mode to
work around attachment failures. An independent MCP runtime also needs the
explicit trusted launch flag: host-local central registry args can be
["mcp", "--grant", "existing-profile"] on an authorized dedicated desktop.
The daemon's grant did not authorize an independently launched MCP runtime.
Keep host-specific authority out of the shared portable template.

With the browser already exposing its PID-owned loopback endpoint, the following
shape worked on Linux with Cua 0.33.4:

```json
{
  "session": "desktop-browser",
  "pid": 12345,
  "window_id": 123456,
  "strategy": {"kind": "existing_profile"}
}
```

Pass it to `browser_prepare`, then `get_browser_state` with the same session,
PID and integer window ID. Require exact native-window binding and mutation
permission before using browser tools. Session, strategy and window types matter:
`session_name`, a string strategy and a string window ID are not equivalents.
Refresh handles after a daemon restart. Cua's automatic existing-profile setup
was not implemented for Brave on this platform, but attachment to an already
configured, verified endpoint worked without changing preferences.

Driver-owned browser processes can exit when the owning daemon stops. A
persistent dedicated profile should be launched by the desktop's supported
startup mechanism, independently of the automation daemon.

For browser settings or secure stdin batching when the primary browser surface
is unavailable, the maintained agent-browser CLI supports an explicit CDP
endpoint. Capture batch output privately: it echoes command arguments, including
secrets. Never print raw secret-bearing batch results. Re-enumerate tabs after a
daemon restart; short tab labels can be reassigned. Match the intended page and
verify it before entering credentials.

SDDM autologin may leave the secret-service keyring locked and block browser
initialization, including page automation. A zero exit from a separate
gnome-keyring-daemon --unlock command did not establish that the running
collection was unlocked. Verify its Locked property on the desktop session
bus. Native dialog entry worked through MCPorter's maintained SDK, with the
protected credential read in process memory and passed in tool arguments;
no password was placed in argv or printed.

For unattended startup, a drop-in on the packaged gnome-keyring-daemon.service
worked with its existing foreground/components/control-directory arguments,
--unlock, and StandardInput=file:<protected-password-file>. This uses the
existing native service, not a custom unlock wrapper. Verify the collection is
actually unlocked after a service restart and an unattended reboot. Export the
desktop session environment before running session-bus or Wayland checks.

A small VM with synced extensions, desktop components and several agent runtimes
can exhaust RAM. Check kernel OOM evidence before blaming authentication or the
browser driver; provide suitable memory and native swap, then recheck the page.

For image boot and native kernel-update checks, see [persistent VM startup](omarchy-vm-startup.md).

A blank page DOM can coexist with a native Chromium or password-manager passkey
popup. Inspect a fresh native desktop/window capture and the active browser
before treating this as a stuck page. Select the exact saved identity through
Cua's native UI; prefer an accessibility token, or a capture-bound pixel click
when the popup is absent from that tree. Verify the signed-in identity afterward.
Do not export passkeys to replace this flow.
