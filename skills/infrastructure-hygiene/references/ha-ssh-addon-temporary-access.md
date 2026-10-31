# Home Assistant SSH Add-on and Config File Access Patterns

## Current state (Luke's choice, 2026-10-29)
The **SSH & Web Terminal add-on is intentionally left running.** Use it for direct filesystem work on HA configuration files (`/config/automations.yaml`, split files under `/config/automations/`, `configuration.yaml` includes, scripts, etc.). Don't stop it, and don't ask Luke to disable it after a task. Changing its state is Luke's call in the HA UI.

Workflow:
1. Get the configured username and port from private context or Luke.
2. Connect with the established key.
3. Read (`cat`, `ls`, `grep`), apply edits, verify.

Earlier guidance kept the add-on disabled by default and enabled it only per task. That rule is superseded.

## API / Token Scope Limitation
A long-lived Home Assistant token only permits regular REST API access.

Tested endpoints (2026-06):
- Success: `GET /api/config` (returns version 2026.5.4, components, etc.), states, services (including automation.*), ha_list_services, ha_get_state, ha_call_service for non-hassio domains.
- Failure (401 Unauthorized): `GET /api/hassio/addons`, addon info/options, supervisor management paths.
- Failure (403 Forbidden): direct `http://supervisor/addons` and similar.
- `ha_call_service` domain="hassio" is explicitly blocked in the tool for security.

**Conclusion**: Cannot use the API to read current add-on options or toggle the SSH feature programmatically. Any enable/disable is a manual UI action by Luke.

## Additional Context from Recon
- Home Assistant is **not** one of the TrueNAS Apps on ${NAS_IP} (absent from `midclt call app.query` results; earlier `docker ps` on the NAS showed no matching containers).
- `homeassistant` resolves to ${HOME_ASSISTANT_IP} on the lab DNS (the router).
- The add-on is the documented, supported path for direct config file access on most HA installs. Direct SSH to the underlying host/VM/LXC (if separately enabled) is an alternative only if the user has set it up outside the add-on.

## Verification Commands (for diagnosing token scope)
```bash
# Should succeed
curl -s -H "Authorization: Bearer $HASS_TOKEN" "http://homeassistant:8123/api/config" | python3 -c '
import sys, json; d = json.load(sys.stdin); print("version:", d.get("version"))
'

# Expect 401 or empty/non-JSON
curl -s -w "\nHTTPSTATUS:%{http_code}\n" -H "Authorization: Bearer $SUPERVISOR_TOKEN" "http://homeassistant:8123/api/hassio/addons" | head -c 100
```

## NFS backup mount DNS diagnosis and recovery

- Check whether the SSH add-on is already running before asking the user to enable it. Existing authorized SSH access can run `ha mounts info`, `ha dns info`, and `ha network info` without disabling protection mode or using Docker. A denied API token in another add-on does not imply that this supported CLI path is unavailable.
- Inspect both A and AAAA responses for the exact configured server. A gateway may override A to the NAS while forwarding AAAA to a public wildcard; successful IPv4 lookup alone does not prove the hostname is safe for NFS.
- When DNS is the failing dependency and the NAS has a stable LAN address, update only the mount through `ha mounts update <name> --type nfs --usage backup --server <nas-ip> --path <existing-export> --read-only=false`. Preserve the original export, usage, and permissions. Do not disable IPv6 globally.
- A CLI timeout is not proof that the Supervisor operation failed. Read `ha mounts info` and recent `ha supervisor logs` before retrying; stopping the old hung mount can outlive the client timeout while the update still completes.
- Require the exact mount to report `active` and host journal evidence of a successful mount. Existing backup archive-format errors are separate from connectivity; do not delete those archives during network repair.
- Use `ha backups --raw-json` for inventory; `ha backups info <slug>` requires a specific backup identifier.

## Public-DNS watchdog false positives

- Compare plaintext DNS with DNS-over-HTTPS before treating a private answer from an explicitly selected public resolver as a public DNS failure. Router DNS interception can redirect even queries addressed to a public resolver.
- Use a validated HTTPS DNS response for public-record checks, enforce DNS status and record type, and compare the resulting A records with the current WAN address. Keep local service DNS and authenticated IMAP/SMTP checks separate.
- After correcting a watchdog, execute the real script and read its persisted health state. Silent output alone may mean duplicate-error suppression, not health.

## Related Skills and References
- `proton-pass-cli` (if the add-on config itself stores secrets or keys).
- `truenas-custom-apps` and the broader infrastructure-hygiene stack (for when HA storage paths or related services on TrueNAS are involved).

Update this reference with any new token scope discoveries, alternative file-access add-ons (File Editor, Studio Code Server), or changes in how the add-on exposes its SSH port/username.

## Session Origin
Derived from investigation after the user asked whether the agent could "modify SSH access in the SSH add-on" and "enable it yourself" via the API (June 2026 session). The disabled-by-default preference stated then was replaced on 2026-10-29: the add-on stays on.

## Rule summary (formerly in SKILL.md)

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

The add-on is intentionally left running (see Current state).

Supervisor and hassio add-on endpoints return 401 or 403 to a normal HA token, and hassio service calls are blocked. The agent cannot enable this add-on through the API. Only Luke toggles it, in the UI.

Additional notes:
- HA is not a TrueNAS app (no `app.query` entry). It resolves to ${HOME_ASSISTANT_IP}.

This is a hygiene rule for the HA portion of the stack.
