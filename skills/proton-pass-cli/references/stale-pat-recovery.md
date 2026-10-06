# Stale PAT session recovery

Observed with CLI 2.4.2: `pass-cli info` can report `failed to authenticate: non-existent session` while `pass-cli login` reports `Already authenticated`. A running SSH agent can simultaneously report `No active session` while its socket still responds.

1. Inspect `info` output and distinguish explicit session rejection from network errors. Connection resets, DNS failures, and timeouts alone do not justify clearing authentication.
2. Stop the existing login monitor during manual repair to avoid concurrent login attempts. Use the deployment's existing service configuration.
3. For confirmed session rejection, run `pass-cli logout --force`, then log in with the existing scoped token through `PROTON_PASS_PERSONAL_ACCESS_TOKEN`. CLI 2.4.2 accepts that environment variable with plain `pass-cli login`; keep the token out of argv and logs.
4. Require successful `info`, vault listing, and share listing before restarting dependent services. Do not rotate a working token or create a broader session merely because its previous session expired.
5. Restart the SSH agent after authentication recovery. Socket reachability alone does not prove that its in-memory client uses the replacement session. Verify identities with `ssh-add -l` using the configured socket, without printing key material.
6. Restart the existing monitor and check that health checks pass without session errors.

When fixing an existing monitor, announce a connectivity wait only after its initial check fails. Accept an active wired connection as well as Wi-Fi, and rate-limit warnings during a continuous failure episode. Do not add a new wrapper or service for this recovery.
