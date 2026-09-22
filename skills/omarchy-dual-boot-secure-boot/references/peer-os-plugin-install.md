# Install Omarchy plugins onto a mounted peer OS

Verified on a live personal session with the work home mounted. Omarchy has
no official plugin lockfile or multi-machine sync. `omaplug` is a live-session
manager. Do not add a custom wrapper, lockfile, or installer.

Third-party plugins are git clones under `~/.config/omarchy/plugins/` and are
not part of the Stow tree. Enabled state lives in
`~/.config/omarchy/shell.json`: a third-party plugin is on only when its id
appears in `bar.layout` or `plugins[]`.

## Install with the official command

1. Confirm the peer home is the unlocked other OS, not the running `$HOME`.
2. Collect remotes from the current OS:

```bash
for d in ~/.config/omarchy/plugins/*/; do
  git -C "$d" remote get-url origin
done
```

3. For each plugin missing from `<peer-os-home>/.config/omarchy/plugins/`:

```bash
HOME="<peer-os-home>" omarchy plugin add <git-url> --yes
```

Do **not** pass `--enable`. Enable talks to the live `omarchy-shell` IPC and
would change the running session's `shell.json`.

4. Treat `Added <id> into ...` as success. `omarchy plugin add` always runs
   `omarchy-shell shell rescanPlugins` afterward. When `HOME` is the peer,
   that rescan may print `omarchy-shell is not responding` and exit 1 even
   though the clone already landed. Confirm with
   `omarchy plugin validate <peer-plugin-dir>`.

## Enable on the peer

Edit the peer `shell.json`. Do not run `omarchy plugin enable` from the
other OS.

- Overlays, panels, and services: add `{"id": "<plugin-id>"}` to `plugins[]`.
- Bar widgets: add a layout entry, or add `omaplug` to the peer bar and place
  the rest after that OS boots.
- Keep peer-specific first-party bar, clock, idle, and transparency settings.
  Do not copy the live `shell.json` wholesale.

## Sync existing checkouts

Omarchy still has no lockfile. When the peer home is mounted, Unison
(official Arch `extra`) can sync the two plugin trees:

```bash
unison -ui text -batch -auto \
  ~/.config/omarchy/plugins \
  <peer-os-home>/.config/omarchy/plugins
```

Do not add a custom path unit, timer, or wrapper around this. Do not point
Unison at `shell.json`. Bar layout and idle settings stay per OS.

## Limits

- Official add clones the repository default-branch HEAD. A dirty working
  tree or non-default branch on the current OS does not transfer. Switching
  branches in the peer checkout is ordinary git.
- Do not copy plugin sidecar secrets such as `ntfy.json`, `sandman.json`, or
  `hass/config.json` unless Luke asks.
- After the peer boots, `omarchy plugin update` and `omaplug` manage that
  OS's copies.
