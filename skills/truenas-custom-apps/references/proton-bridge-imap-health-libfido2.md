# Proton Bridge IMAP health, libfido2, and midclt lifecycle (TrueNAS custom app)

`proton-bridge` can report RUNNING and accept TCP on `127.0.0.1:1143` while IMAP never completes a greeting. A mail client then hangs and no mailbox can be read.

## Symptoms

- TrueNAS: `midclt call app.query` → `proton-bridge` state `RUNNING`; `ss -tlnp` shows `127.0.0.1:1143` via `docker-proxy`.
- A mail client stalls after connect: the log shows the list command starting and then nothing.
- An IMAP probe returns **no greeting** (empty stdout) even though TCP connect succeeds **when the probe matches the configured encryption mode**:
  ```bash
  printf 'a0 CAPABILITY\r\n' | timeout 5 nc 127.0.0.1 1143
  ```
  A plaintext CAPABILITY probe against an implicit-TLS Bridge endpoint is expected to be empty and is not evidence of a broken vault. Check the known-good consumer's host, port, and encryption mode first; a bounded authenticated client probe is stronger evidence than a raw socket greeting.
- Container logs: `Welcome to Proton Mail Bridge interactive shell`, `not able to detect a supported password manager`, Bridge auto-update (e.g. `3.24.2`, `3.25.0`), then:
  `error while loading shared libraries: libfido2.so.1: cannot open shared object file`
- May also see `FATA[...] Failed to launch error="signal: killed"` with `launcher_version=3.19.0` / `exe_to_launch=bridge` in log tail or when invoking `--cli info` against a half-broken vault.
- `docker exec proton-bridge protonmail-bridge --cli info` may print only launcher `FATA` / `exit status 127` lines with the libfido2 path under `bridge-v3/updates/<version>/bridge` — treat that as the same class of failure as log tail, not proof that IMAP is up.
- Minimal bridge data under volume (e.g. `ls` shows only `.` / `..`, or a lone config file under `bridge-v3`) → full Proton login / vault never completed. Logs may show `Could not load/create vault key` and `no keychain` even while socat listens on 1143.
- **`midclt call app.stop` + `app.start` does not populate an empty data dir** — IMAP stays silent until a human completes Proton password init (see `proton-bridge-pass-automation.md`).

**Do not treat `nc -z` alone as “bridge OK”.** Run `scripts/probe-bridge-imap.sh` (or a CAPABILITY probe in the same TLS mode the client uses) before treating the mailbox as readable.

## libfido2 (temporary vs durable)

After Bridge self-updates inside `shenxn/protonmail-bridge:latest`, the launched `bridge` binary may require `libfido2.so.1` while the image does not ship it.

**Ephemeral fix (lost on container recreate):**
```bash
ssh -o IdentityAgent=none -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" -i "$NAS_SSH_KEY" "$NAS_SSH_TARGET" \
  'docker exec proton-bridge bash -c "apt-get update -qq && apt-get install -y -qq libfido2-1"'
```
Then confirm the library exists: `docker exec proton-bridge ls /usr/lib/x86_64-linux-gnu/libfido2.so.1`.

**Lifecycle pitfall:** installing `libfido2-1` via `docker exec`, then calling **`midclt call app.stop` + `app.start`**, recreates the container from the image and removes the hotfix. With an **empty** data volume (`ls` → only `.` / `..`), restart still leaves CAPABILITY empty and logs show the welcome shell plus `Could not load/create vault key`. Stop after a failed probe and say the mailbox is incomplete. Either reinstall libfido2 after every midclt recreate, or `docker restart proton-bridge` when only the process needs a kick (that keeps the container filesystem until the next midclt redeploy). **Never** midclt stop/start as a retry after a successful apt install unless you apt install again immediately after `RUNNING`. Run `scripts/probe-bridge-imap.sh` first. If it reports `imap_no_response`, do not chain a restart into a long mail-client read. A Pass field that holds the relay password does not change this.

**Durable fix (preferred):** bake `libfido2-1` into the custom app (custom image FROM shenxn + `RUN apt-get install -y libfido2-1`, or an entrypoint hook that installs once per start before launching Bridge). A manual `docker exec apt-get` does **not** survive `midclt call app.stop` + `app.start` because the container is recreated from the image.

Installing libfido2 alone does not fix IMAP if the account vault was never initialized (interactive Proton password still required). See `references/proton-bridge-pass-automation.md`.

## Proton API TLS mismatch caused by DNS/routing interception

A separate but compounding failure signature is repeated Bridge log output such as:

```text
Get "https://mail-api.proton.me/tests/ping": tls: failed to verify certificate:
x509: certificate is valid for <internal-traefik-host>, not mail-api.proton.me
```

This indicates that `mail-api.proton.me` reached an internal Traefik endpoint (or another intercepted destination) and presented the wrong certificate. Diagnose it as a resolver/routing problem rather than a generic Proton outage:

1. Check `getent hosts mail-api.proton.me` (or equivalent) inside `proton-bridge` and on the NAS.
2. Compare the result with an external resolver and inspect Docker/NAS DNS configuration, wildcard rewrites, and internal proxy rules.
3. Probe the certificate/SNI path from inside the container before changing Bridge account state.
4. Repair DNS/routing first; restarting or reinitializing Bridge while the API hostname is intercepted will not produce a healthy mailbox.

This may coexist with `app.query=RUNNING`, a TCP-open 1143 listener, empty banner/CAPABILITY, and an empty persistent data directory. Record those as independent observations. A successful Proton Pass relay-password lookup proves credential access only; it does not prove Bridge initialization, API reachability, or IMAP readiness.

## midclt lifecycle (TrueNAS)

- `midclt call app.restart proton-bridge` → **`Method does not exist`** on this stack.
- Use: `midclt call app.stop proton-bridge` then `midclt call app.start proton-bridge` (async job IDs returned); poll `app.query` until `RUNNING`.
- `docker restart proton-bridge` recreates/restarts the container but does not replace a broken vault; combine with data-dir inspection.

## Secondary CLI pitfalls

- `docker exec proton-bridge protonmail-bridge --cli info` while entrypoint already runs `bridge --cli` may log `Failed to create lock file; another instance is running` and keychain/dbus warnings. Prefer log tail + IMAP CAPABILITY probe for cron health checks.
- Redact mailbox passwords from any `info` output in summaries.

## Verification checklist (IMAP actually serving)

From the same network/container path as the intended consumer:

1. Determine the endpoint's real protocol from a known-good client or Bridge configuration. For plaintext/STARTTLS, probe with `openssl s_client -connect <host>:<port> -starttls imap`; for implicit TLS, use `openssl s_client -connect <host>:<port> -servername <hostname> -verify_hostname <hostname>` and then issue CAPABILITY inside the TLS session.
2. Verify DNS and certificate authorization from the consumer container, not only from the NAS host. NAS-local loopback binds may be unreachable from sibling app containers.
3. Run one bounded authenticated IMAP command from the real client. A successful list outweighs an ambiguous empty raw greeting probe.

If that probe fails or times out, report the mailbox incomplete. Do not classify mail as empty.

## Related

- `scripts/probe-bridge-imap.sh` — CAPABILITY probe. No secrets printed.