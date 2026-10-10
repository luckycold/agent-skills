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
work around attachment failures.

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

SDDM autologin may leave the secret-service keyring locked. Use the native
`gnome-keyring-daemon --unlock` stdin interface with an authorized, protected
local credential rather than exposing the password in argv or inventing an
unlock service. Verify persistence after reboot.

A small VM with synced extensions, desktop components and several agent runtimes
can exhaust RAM. Check kernel OOM evidence before blaming authentication or the
browser driver; provide suitable memory and native swap, then recheck the page.
