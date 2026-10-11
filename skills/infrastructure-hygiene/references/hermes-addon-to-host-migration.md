# Hermes: migrate from the Home Assistant add-on to a host install

Verified 2026-10-11 (Hermes v0.21.x, add-on 1.3.7, HAOS on a Proxmox VM). Resolve hosts, VM IDs, slugs, and IPs from `~/.agents/private-context.md`.

## Reach the add-on without the SSH add-on

- If the SSH add-on rejects the agent's key, run commands in HAOS through the hypervisor guest agent: `qm guest exec <haos-vmid> --timeout <s> -- docker exec <addon-container> bash -c '<cmd>'`. The result is JSON (`out-data`, `err-data`, `exitcode`). Base64-encode multi-line scripts to avoid nested quoting.
- A background process dies when the exec ends. Use `setsid nohup <cmd> >log 2>&1 </dev/null & disown`.
- Supervisor CLI: `docker exec hassio_cli ha apps info|stop|uninstall <slug>` (`apps`, not `addons`). The add-on `/config` lives at `/mnt/data/supervisor/app_configs/<slug>`, not `addon_configs`.
- File transfer: generate a one-shot ed25519 key in the container `/tmp`. On the target, append `from="<ha-ips>",restrict,command="cat > <dest>" <pubkey>` to `authorized_keys`, stream the file over SSH stdin, compare `sha256sum`, then delete the key on both sides.

## Move the profile

1. Keep the target's fresh official install (newer code is fine). Snapshot it first with `hermes backup -o <file>`.
2. On the add-on, run `hermes backup -o /config/<file>.zip`. It snapshots SQLite safely and skips code, venvs, `node_modules`, `.git`, and caches. `SQLite safe copy failed` on `proton-pass/agent-session.corrupt-*` is harmless.
3. Stop the target's desktop app and `hermes serve` before `hermes import --force <zip>`.
4. **`hermes import` installs and starts the `hermes-gateway` user service.** Stop it immediately (`systemctl --user stop hermes-gateway`) until the add-on is stopped; only one gateway may poll a Telegram bot token.
5. Import drops file modes. Run `chmod -R go-rwx ~/.hermes`, then restore `+x` from a `find . -type f -perm -u+x` list taken on the source.
6. `.git` is excluded. Re-clone git-installed plugins (for example `plugins/homeassistant`) at the source commit and move the `.git` directory into place.

## Rewrite add-on assumptions

Find live references with `grep -rIl /config ~/.hermes`, ignoring `.bak*`, logs, sessions, and cron output.

- `config.yaml`: `terminal.shell_init_files`, `skills.external_dirs` (use `~/.agents/skills`), hook commands, and `mcp_servers.*` command/env (`MCPORTER_CONFIG`, `PATH`).
- `.env`: `HASS_URL` (`http://homeassistant` resolves only inside HA; probe which port HA core actually serves), `HERMES_COPILOT_ACP_COMMAND`, and `API_SERVER_HOST=0.0.0.0` when HA must reach the API.
- `cursor_agent.json` (`agent_path`, projects) and `hermes cron edit <id> --workdir <path>`.
- Set `hermes config set timezone <tz>` when the host clock differs from HA's, or cron schedules shift.
- Hook consent is keyed by path. Start the gateway once after `systemctl --user set-environment HERMES_ACCEPT_HOOKS=1`, then unset it and `hermes hooks revoke <old-path>`. `hermes hooks test` does not record consent.
- The dotfiles-sync hook restows on Stow hosts. `dotfiles_management.bash` is not nounset-safe, so source it in a `(set +u; export DOTFILES_SCOPED_AGENT=1; ...)` subshell so the gateway does not bulk-render secrets with a scoped Pass token.
- mcporter: one registry server that needs `uvx` makes listing fail with `Unable to resolve configured executable from the effective PATH`. Include mise's uv bin directory in the MCP env `PATH`. With the dotfiles registry, Kagi tools are named `kagi-ken__*`.
- The `cursor_agent` plugin needs a binary named `agent`. Grok's installer shadows it in shells via `~/.grok/bin`. A `~/.local/bin/agent` link to Cursor serves the gateway `PATH`. `hermes doctor` can still show it unmet, so confirm in the gateway log.
- The add-on image ships `agent-browser`. On a host, run `npm install -g agent-browser@<same-version> && agent-browser install`.
- Pass: log the host's scoped session in with Hermes' existing scoped `agent.env`. Use any owner web login only in a separate session directory, then `logout --force` and delete it.

## Re-point Home Assistant

- Confirm HA core reaches the new API first: `docker exec homeassistant curl -s http://<host>:8642/v1/health`.
- The `hermes_conversation` integration has no reconfigure step. With an admin token, delete the old entry, run `POST /api/config/config_entries/flow` (handler `hermes_conversation`: host, port, `api_key` = `API_SERVER_KEY`, `use_ssl`, `profile_route: native`), then submit the old options through the options flow. Delete-then-add keeps `conversation.hermes_agent` and Assist pipeline references. Verify with `POST /api/conversation/process`.
- The add-on published the Android relay (container 9119) on a different host port. Phones must be repointed to the new host.
- `ha apps uninstall <slug>` without `--remove-config` keeps `app_configs/<slug>` as a rollback copy.
