---
name: infrastructure-hygiene
description: Class-level devops hygiene for Luke's Hermes/TrueNAS/Home Assistant stack — harness boundaries, update/stash audit, read-only recon, TrueNAS Traefik/ACME/apps; cross-links proton-pass and web-search skills.
author: Luke
category: devops
---

# Infrastructure Hygiene

Class-level devops hygiene for user-owned infrastructure (Hermes container, TrueNAS, Home Assistant add-on, LAN hosts). Prefer conventional, UI-visible, recoverable setups over one-off hacks.

## Core Principles
- Never modify core code harnesses, especially the Hermes agent harness itself.
- The user considers their infrastructure (including the Hermes container and TrueNAS) to be user-owned. The agent is expected to keep it tidy and conventional.
- Prefer clean/official update paths or fresh sessions over local patches and workarounds.
- When redundant or hacky installations are discovered, clean them up immediately.
- **Enforcement**: harness and hygiene rules override the general desire to be helpful. When the user expresses frustration about harness modifications, consult this skill before touching Hermes core files.

## Hard Rules — Hermes code harness (non-negotiable)

Do not modify the Hermes code harness or core agent files under any circumstances. The harness was designed a certain way for a reason; local modifications, even "temporary" ones, are not acceptable.

### Prohibited actions
- Editing core files such as `agent/codex_responses_adapter.py`, `agent/chat_completion_helpers.py`, provider adapters, session/reasoning handling logic, or anything under `hermes-agent/agent/`
- Adding workarounds, monkey-patches, or custom encrypted-state handling
- Modifying how sessions, providers, or toolsets are initialized

### Correct response when something is broken
- Report the issue clearly
- Offer to start a fresh session
- Suggest official update mechanisms (`hermes update`, gateway restart, new session)
- Never patch the harness to make the current session work

### Related preferences
- Prefer clean, conventional, maintainable setups over clever workarounds
- When redundant or leftover installations are discovered (duplicate Node, stray Homebrew in temp paths), clean them up proactively
- Use proper s6 services for long-running components that must survive restarts

See `references/hermes-harness-boundary.md` for the incident that established this boundary.

## Hard Rules — operational
- **Redundant Installs**: When multiple versions of a tool or duplicate installations are found, remove the leftover/hacky one.
- **Direct Action**: When the user approves a change via tool confirmation, execute it without asking for further confirmation.
- **Tool approval ≠ chat approval**: Destructive `rm`/`zfs destroy`/`app.delete` may still require the **runtime tool-confirmation prompt**. Chat “approved / try again / do it” is not enough if the tool returns `BLOCKED: user has NOT consented`. Do not loop rephrases; ask Luke to approve the next tool popup, then retry once.
- **Home cleanup phases (Luke):** Prefer phased tidy. **HA entity unavailable/unknown purge is Phase C only** unless Luke explicitly asks for it in the same turn. Prefer stock Hermes + one intentional HA dashboard/Kagi local commit; keep `minecraft-modded` data until the ATM project is finished or Luke says otherwise.
- **Live Stow profile changes:** Do not unstow an entire active persona merely to relocate one subset. Required files can disappear between commands and trigger live reload failures (for example, Hyprland reporting a missing `hypr.autostart` module). Prepare the replacement first, relink/restow the narrow paths without a gap, then validate affected runtimes. For Hyprland, run `hyprctl reload` followed by `hyprctl configerrors`.
- **Desktop configuration deployment:** Identify the host running the user's desktop and its active configuration before claiming a shortcut change is applied. Editing or pushing a headless host's dotfiles checkout does not update another host. Update the desktop checkout, verify the active Stow link and dry run before any restow, reload the affected runtime, and inspect the loaded binding. If desktop access is unavailable, report the saved change separately from deployment and provide the exact command the user can run on that desktop.

## Pitfalls to Avoid
- Local modifications to protected harnesses
- Leaving behind temporary or `tmp/.cellar` style installations
- Explaining what you will do instead of doing it when the user has already approved
- **Do not reintroduce `wg-home-auto`.** Luke retired the periodic Proton/home WireGuard SSID auto-switcher (30s systemd timer plus `/usr/local/bin/wg-home-auto`) as more trouble than help. It is gone from the dotfiles repo; if leftovers remain on a host, disable the timer and delete the unit/script rather than restoring them from git history. Leave existing `/etc/wireguard/*.conf` tunnels unless he asks to remove those too.

## Appliance storage prepared on another host

Before booting an appliance whose filesystem you staged from a desktop, restore its filesystem root to the owner the appliance expects (normally `root:root`). Change only that directory, not games or user data. A `Detected unsafe path transition` error from systemd-tmpfiles is the signature. Prefer the shipped tmpfiles/mount-unit repair over custom startup scripts. See `references/appliance-storage-ownership.md`.

## Hermes container (Home Assistant add-on)

- **Weekly maintenance:** treat `/config` as home. Inspect before changing anything. Never print secrets. Never run `npm update -g`; install pinned versions instead (`kagi-cli@0.12.0` on glibc 2.36, `mcporter@0.13.8` on Node 22). Don't create or edit cron during unattended runs. Be conservative with `hermes update` and gateway restarts. Fix `UU`/conflict markers in core files before relying on tools. Full rules and follow-up checklists: `references/hermes-container-weekly-maintenance.md`.
- **Kagi search/MCP:** Kagi is nested under the **mcporter** MCP, not a top-level `kagi` server. Re-probe schemas after every kagi-cli bump with `references/kagi-mcp-schema-probe.py`. Keep Kagi outside Hermes core. See `references/hermes-kagi-mcp.md`.
- **Cron jobs:** use `hermes cron create` with a self-contained prompt, explicit `--skill`, and `deliver=local` for low-noise jobs. See `references/hermes-cron-creation.md`.
- **Update/stash hygiene:** audit stashed local changes by blast radius. Keep only narrow integrations at supported seams, plus Luke-approved HA dashboard base-path patches. Drop core/provider/fallback changes. See `references/hermes-update-stash-audit.md`.
- **New Grok/xAI OAuth models:** use the supported catalog/config path and a real one-shot smoke, and set `model.context_length` to the real window. See `references/hermes-xai-oauth-new-model-enablement.md`.
- **Migrating off the add-on:** use `hermes backup`/`hermes import`, stop the gateway that import auto-starts, restore modes and plugin `.git`, rewrite `/config` paths, and re-point the `hermes_conversation` integration. See `references/hermes-addon-to-host-migration.md`.
- **Headless Obsidian:** prefer the official `obsidian-headless` (`ob`) client for Sync. See `references/headless-note-vault-cli.md`.

## Read-only infrastructure reconnaissance

When Luke asks you to "learn" a host, do an active but read-only pass: DNS, reachability, ports, TLS, and unauthenticated status endpoints. Correlate with HA/UniFi trackers and NAS proxy configs, and pivot through a trusted LAN host when the container's vantage is limited. Label fingerprinting as an estimate. Report exactly what remains inaccessible and the cleanest access path. Save durable topology facts (never credentials) to private context. See `references/readonly-infrastructure-recon.md`. For Luke's Proxmox lab, load `proxmox-homelab` first; generic Proxmox: `references/proxmox-readonly-recon.md`, `references/proxmox-cluster-ceph.md`.

## Proton Pass CLI for audited agent secrets

Use the **`proton-pass-cli`** skill for install, agent tokens, wrappers, `PROTON_PASS_AGENT_REASON`, headless `fs` key provider, and session repair. Resolve Luke's exact password-manager topology and local integration paths from `~/.agents/private-context.md`.

## Agent hosts and CLIs on the LAN

- **Codex Remote on TrueNAS:** treat it as a separate host-agent migration with personal skills under `~/.agents/skills/` and transport over SSH or local sockets. See `references/codex-truenas-remote-control.md`.
- **Unresponsive T3 on a small Linux VM:** compare client disconnect timestamps with guest memory pressure, swap occupancy, and process RSS before restarting. See `references/t3-memory-pressure-recovery.md`.
- **Temporary T3 scheduler takeovers:** saved tasks can retain the provider/model captured at creation after their destination thread changes provider. Verify the provider on a dispatched queued run. If the native update API cannot change it, recreate from the desired provider with stable request IDs, preserving prompts, schedules and state; disable old tasks after replacements exist. Rewire webhook producers to the replacement URL and test delivery separately. Arrange native expiry cleanup for every owned task, including webhooks that may never fire again.
- **T3 Connect on TrueNAS:** use the official user-systemd service with a loopback listener. Build `node-pty` in a temporary container, not with a host toolchain. Treat link codes as secrets. See `references/t3-connect-truenas-host-service.md`.
- **Agent CLIs on Proxmox/TrueNAS/PBS/HA:** stow `common` then `personal`, and keep binaries and auth outside Stow. On HA, use the Debian Hermes add-on, not the Alpine SSH add-on. See `references/agent-clis-lan-hosts.md`.

## TrueNAS apps

- **Deployment preference:** (1) a catalog app, (2) a custom app through the Apps UI or middleware (`midclt call -j app.create/app.update`), (3) raw compose only when Luke asks. Apps must stay visible in the TrueNAS UI. Keep data under `/mnt/Apps/Applications/<service>` as bind mounts. Keep Postgres/Redis private. Put private routes behind `authelia@file`. See `references/truenas-app-deployment-conventions.md`, `references/truenas-custom-app-cli-registration.md`, and the `truenas-custom-apps` skill.
- **DNS vs Traefik IPs:** the TrueNAS host nameserver must point at the LAN resolver that holds the local records (now the router; formerly `adguard-home`), with no public fallback. Changing resolvers: `references/lan-dns-resolver-migration.md`. Never rewrite app hostnames to the NAS UI address. Verify with `dig` and `curl --resolve`. See `references/truenas-adguard-dns-and-traefik-ips.md`, `references/truenas-docker-dns-recovery.md`, `references/truenas-cloudflared-adguard-dns-origin-resolution.md`, and `references/truenas-plex-docker-dns-recovery.md`.
- **Traefik exposure and certificates:** use a small dedicated dynamic file. Issue ACME certificates for out-of-SAN hosts with `midclt call -j`. See `references/truenas-traefik-app-routing.md`. For renewal, run `certificate.renew_certs` as a job and verify the dates. A Cloudflare `Cannot use the access token from location` error means an IP-restricted token. See `references/truenas-acme-renewal.md`.
- **Public exposure lockdown:** Authelia on every router except an explicit bypass list (audit file + Docker label routers), check Cloudflare Tunnel ingress and Authelia network/path bypasses for hidden holes (replace blanket ones with per-app API bypasses; a LAN-wide skip needs tunnel-connector exclusions), and restrict Traefik to Cloudflare + private ranges. See `references/traefik-authelia-default-and-origin-lockdown.md`.
- **ninerouter/9Router:** `references/truenas-ninerouter-9router-maintenance.md`.
- **Apps pool space:** prune unused Docker images first, and verify mounts before deleting anything. See `references/truenas-apps-pool-space-reclaim.md` and `references/truenas-zfs-dataset-busy-delete.md`.
- **Backrest/restic and Immich backups:** Immich usually already has a plan, so inspect the mounts and logs before creating one. See `references/truenas-backrest-restic-path-health.md` and `references/immich-proton-cli-verification.md`.
- **qbit_manage:** mirror the existing tracker-tag convention. Never raise the orphan threshold or delete orphans without a read-only manifest and hard-link audit. See `references/truenas-qbit-manage-retention-and-orphan-forensics.md`.
- **Game managers:** `references/game-manager-readonly-trials.md` (RetroArr/Questarr) and `references/gamarr-hardlink-emudeck-trial.md`. For PS3 archive imports into RomM, keep sources seeding, use `makeps3iso`, and verify the RomM DB row; see `references/truenas-romm-ps3-imports.md`.
- **Hosted alternatives:** treat privacy as architecture. Separate true zero-knowledge E2EE from policy-based managed plaintext, and say when no equivalent exists. See `references/truenas-hosted-app-alternatives.md`, `references/truenas-hosted-privacy-alternatives.md`, and `references/truenas-app-retirement-hosted-alternatives.md`.

## Home Assistant config access

Keep the **SSH & Web Terminal add-on disabled by default**. Luke enables it temporarily when `/config` file work is needed. Agent tokens cannot manage add-ons through the Supervisor API, so ask him to toggle it in the UI and to disable it afterward. HA is not a TrueNAS app. See `references/ha-ssh-addon-temporary-access.md`.

## Other references

`references/index.md` has the full descriptions. Also: `references/hermes-harness-boundary.md`, `references/laptop-lan-recon.md`, `references/netbird-bmc-work-pc-dual-homed.md`, `references/unifi-port-forwarding-via-api.md`, `references/unifi-dhcp-dns-via-api-and-ip-diagnostics.md`, `references/unifi-split-horizon-dns.md` (forward domains, wildcard A not blocking AAAA, Cloudflare ECH/IPv6 off), `references/unifi-iot-internet-allowlist-via-api.md` (IoT internet default-deny + allowlist), `references/rpi-otbr-docker-appliance.md`, and `references/application-mcp-transport-and-placement.md`.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical package under `~/.agents/skills/` when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Make the smallest evidence-backed edit, do not record secrets or transient state, and do not infer a durable preference from one request. Follow the `personal-skill-maintenance` skill for the full review and verification workflow.
