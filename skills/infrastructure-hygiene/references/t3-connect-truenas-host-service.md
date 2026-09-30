# T3 Connect on an always-on TrueNAS host

Use this when T3 Connect should expose an always-on TrueNAS coding environment through T3 Code. Resolve the SSH target and private operational values at runtime; never store the account email, authorization code, challenge URL, or relay credentials here.

## Deployment model

T3's supported background-service path is a user systemd unit, not a TrueNAS Custom App. Keep its runtime and mutable data under a persistent Apps-pool directory such as `<apps-pool>/Applications/t3code`, bind the local server only to loopback, and use T3's managed outbound relay for remote access.

For new installations, prefer the official standalone installer at `https://t3.codes/install.sh`, followed by `t3 service install`. The standalone runtime does not require host Node.js, npm, or a compiler; the build-container procedures below apply to legacy npm installations. Do not replace a live legacy relay from inside its only connected thread.

If `~/.local/bin` is a Stow directory symlink, use the installer's supported `T3CODE_INSTALL_BIN_DIR` setting for a host-local prefix. Before installing the service, unfold `~/.config/systemd` with Stow's `--no-folding` option so the generated unit and enablement link stay outside the dotfiles checkout. Recheck the checkout after installation.

On a host with a relocated `CODEX_HOME`, verify authentication from the service's environment as well as the login shell. A shell reporting logged-in does not prove T3's Codex probe is authenticated. Use the provider's supported credential migration or sign-in flow, keep credentials outside tracked files, and require a fresh T3 provider check.

For a root-owned installation, enable lingering so the user manager survives logout:

```bash
loginctl enable-linger root
systemctl --user enable t3code.service
```

## Native dependency failure on the TrueNAS host

`npx t3 service install` can fail while building `node-pty` when the appliance host lacks `make` or a compiler. Do not add an unmanaged host build toolchain merely to complete the install.

Instead:

1. Select a supported prebuilt Node.js release for the NAS architecture and place it under the persistent T3 base directory.
2. In a temporary Debian/glibc container with the same architecture and Node release, install T3 and compile its native dependencies.
3. Copy the resulting runtime tree into a versioned directory under the persistent T3 base.
4. Run T3's service installer from that runtime.
5. Add a systemd user-unit drop-in that prepends the persistent Node `bin` directory and T3 runtime to `PATH`; then run `systemctl --user daemon-reload`.

The build container's libc and architecture must match the NAS host closely enough for `node-pty` to load. Validate by starting the real service, not merely by checking that `npm install` completed.

## Remote self-update when the NAS has no build toolchain

The web-triggered updater also runs `npm install` on the host. If it reports `Could not prepare t3@<version>`, inspect the newest npm debug log first. A `node-pty` fallback ending in `gyp ERR! stack Error: not found: make` is the same appliance-host limitation as initial installation, not a relay or disk failure.

Pre-stage the exact version requested by the connected client without touching the running service:

1. Use a unique staging directory under `<t3-base>/runtime/versions/`; refuse to proceed if either it or the final exact-version directory already exists.
2. In a temporary Debian/glibc container with the same architecture and Node release as the launcher, bind-mount only the versions directory and run `npm install --prefix <staging> --no-fund --no-audit t3@<exact-version>`.
3. On the host, load `node-pty` with the launcher's Node binary and run the staged `dist/bin.mjs __service-preflight --database-path <t3-db> --launcher-protocol 2`.
4. Only after both checks pass, write `.install-complete` containing the exact version and atomically rename the staging directory to `<t3-base>/runtime/versions/<exact-version>`.
5. Confirm `service-state.json` still selects the old version and the unit PID is unchanged. The client Update action will now reuse the validated runtime, then the stable launcher performs its normal trial, database snapshot, commit, or automatic rollback.

Never edit `service-state.json` to force activation. Do not trigger the final Update action from inside the only active T3 thread; it intentionally restarts the server child and briefly disconnects clients.

## Headless account link

Run the link command in an interactive terminal multiplexer so SSH disconnects do not discard the prompt:

```bash
tmux new-session -s t3-connect
t3 connect link --headless --base-dir "$T3_BASE"
```

Open the displayed URL in an authenticated browser, approve the narrowly scoped T3 CLI consent, and enter the one-time authorization code only into the waiting terminal. Treat the URL, state, challenge, and code as transient secrets: do not put them in shell history, logs, reports, or skills.

After authorization is stored, restart the service so it provisions the environment link and managed relay:

```bash
systemctl --user restart t3code.service
t3 connect status --base-dir "$T3_BASE"
```

## Verification

Require all of the following:

- `t3code.service` is enabled, active, and `SubState=running`.
- `loginctl show-user root -p Linger --value` returns `yes` for a root-owned service.
- `NRestarts=0` after a clean startup.
- The T3 listener is bound to loopback, not an all-interface address.
- `t3 connect status` reports exposure enabled, a stored credential, a provisioned environment link, and an available relay.
- In the client, **Settings → Connections → Remote environments** lists the host as `Available · Relay online`; select **Connect** to make it the active environment.
- Recent service logs contain no errors.

A stored credential with `Environment link: pending server startup` is not complete. Restart the service and wait for provisioning. A provisioned relay also does not automatically select the remote environment in each client, and the project sidebar does not act as a machine list. Connect to the host under Connections, then add or select a project separately. Do not expose the local T3 port through router NAT or Traefik when the managed relay is working.

## Cursor provider is opt-in on the T3 server

A working `cursor-agent` binary and a logged-in CLI session are not enough for T3 Code to list Cursor. In T3 0.0.33, Codex/Claude/Grok/OpenCode default to `enabled: true`; Cursor defaults to `enabled: false` and is labeled Early Access. If `<t3-base>/userdata/settings.json` is missing, those defaults apply and the server cache reports Cursor as disabled without probing PATH.

Verify on the T3 host, not the client laptop:

```bash
cursor-agent status
python3 -c 'import json; print(json.load(open("<t3-base>/caches/cursor.json"))["message"])'
test -f <t3-base>/userdata/settings.json && echo present || echo missing
```

A cache message of `Cursor is disabled in T3 Code settings.` means enable it in the client that is connected to this environment: **Settings → Providers → Cursor**. Writing `providers.cursor.enabled: true` into `userdata/settings.json` only takes effect after the running `t3code.service` reloads settings; do not restart that unit from inside an active T3 thread.

T3 spawns `cursor-agent` (not `agent`). On this host `agent` may be Grok. After enablement, T3 0.0.33 also rejects a Cursor CLI whose `~/.cursor/cli-config.json` `channel` is set to anything other than `lab`; an unset channel plus CLI `2026.04.08` or newer is accepted.

## Agent CLIs and Proton Pass on the NAS root home

Stow `common` onto the TrueNAS root home the same way as the Proxmox nodes. Do not stow `personal` (Hyprland Brave autostart) or `root/`. Keep Codex’s real `~/.codex` tree and `t3code.service` as folded/host-local files so Stow does not replace them. Use a user-local `stow` binary; TrueNAS `apt` is disabled.

Install Cursor Agent, Grok, and Proton Pass CLI with their official installers into `$HOME/.local/bin` (Grok also lands under `$HOME/.grok/bin`). Add a `t3code.service` drop-in that prepends those directories to `PATH` and sets `PROTON_PASS_SESSION_DIR` plus `PROTON_PASS_KEY_PROVIDER=fs`. The Grok installer may overwrite a Cursor `agent` symlink; keep `cursor-agent` as the Cursor binary name.

Create a narrowly scoped Pass CLI agent (viewer, vault Main) and a non-interactive wrapper session on the filesystem key provider. Render `~/.agents/private-context.md` with `pass-cli inject` at mode 600. Enable a oneshot user unit that logs the wrapper in on boot. Delete any leftover owner-bootstrap session after the scoped agent works.

### Native CLI login on a headless T3 host

Check existing sessions before starting fresh logins. When T3 preview tools report no connected desktop browser, run the vendors' native flows in persistent interactive terminals and have the user approve the printed links in their browser:

```bash
claude auth login --claudeai
NO_OPEN_BROWSER=1 cursor-agent login
grok login --device-auth
opencode --pure auth login --provider openai --method "ChatGPT Pro/Plus (headless)"
```

Claude requires its returned one-time code in the same waiting process. Cursor, Grok, and OpenCode poll for approval and finish automatically. Put clickable links and device codes directly in the thread, not only in asynchronous question inputs. Keep authorization codes, challenge URLs, account identities, and credential values out of tracked files and final summaries; redact code input echoed by a terminal. Use `--pure` to keep unrelated OpenCode plugin authentication failures out of the provider-login flow.

Verify with `claude auth status`, `cursor-agent models`, `grok models`, and `opencode --pure auth list`. Cursor can report `Login successful` with `unable to fetch user details` even when a saved token is invalid; require a successful authenticated model listing. OpenCode should list OpenAI with OAuth credentials. Keep credential files at mode `0600` outside the dotfiles tree: Claude uses `~/.claude/.credentials.json`, Cursor `~/.config/cursor/auth.json`, Grok `~/.grok/auth.json`, and OpenCode `~/.local/share/opencode/auth.json`.

T3 provider caches can retain a previous unauthenticated result after the CLI login succeeds. Distinguish CLI verification from a fresh T3 provider check; do not restart the active T3 service just to clear a cache. Cursor may also replace its Stow-linked `~/.cursor/cli-config.json` with a host-local file containing account metadata. Inspect and preserve that file if a later restow conflicts; never adopt it into tracked configuration blindly.

Authenticator pages can fail Cloudflare Turnstile, and Pass may hold only an alias with no password for an SSO identity. If native browser approval is blocked, copy an existing same-account workstation CLI session file onto the NAS at mode `0600`; do not print it or store passwords in skills. Verify authentication rather than file presence alone.

For the same CLI/Pass/skills setup on Proxmox or Home Assistant, see `agent-clis-lan-hosts.md`. Do not install T3 on those hosts.

## Retirement of the host agent setup

When the user asks to remove this setup, treat it as removal of the host installation, not just its Apps entry:

1. Inventory user/system units, native app-server processes, TrueNAS startup tasks, user homes, credential stores, runtime directories, and container mounts. Record existing managed app states. Confirm whether a separate AI gateway should stay; retain shared mail, DNS, backup, and access services according to scope.
2. Check worktrees and generated projects before deleting state. Preserve user project source in an ordinary directory outside the retired runtime.
3. Use `t3 connect logout --base-dir <t3-base>` followed by `t3 service uninstall --base-dir <t3-base>`. Stop Codex with its native daemon command when managed; an unmanaged server may require SIGTERM to its verified PID. Do not stop the service carrying the only active cleanup session.
4. Disable and remove dedicated Pass login/SSH-agent units and drop-ins. Remove only the TrueNAS startup task that enables lingering for this setup, then disable root lingering if no retained user service requires it. Delete local scoped credential copies; do not revoke an agent token shared by other hosts.
5. If Stow was installed solely for this host setup, dry-run its uninstall, unlink the relevant packages, and restore verified original shell startup files with installer blocks removed before deleting the checkout. Remove agent binaries, histories, caches, temporary keys, imported skills, and host-local tool runtimes from every affected home. Preserve ordinary authorized SSH keys and NAS maintenance files.
6. Remove orphan agent datasets through TrueNAS middleware after checking references. A dataset-busy error can come from bind mounts in another mount namespace; see [dataset busy cleanup](truenas-zfs-dataset-busy-delete.md). Do not recursively delete through mountpoints.
7. Verify the NAS UI on its configured bind address, middleware/nginx/Docker health, retained app states, absence of agent processes/listeners/state, and removal of startup hooks. A loopback UI probe can fail when nginx binds only the NAS address.
