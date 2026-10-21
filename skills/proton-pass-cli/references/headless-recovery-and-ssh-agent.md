# Headless session troubleshooting and scoped SSH agent

Linked from the proton-pass-cli skill.

## Missing or corrupted local session in a headless add-on

Resolve the wrapper, token env file, session directory, SSH-agent paths, and watchdog from `~/.agents/private-context.md`; do not persist them in this skill.

1. Run the wrapper's `info` command.
2. If no authenticated client exists, confirm the scoped PAT is available to the wrapper as an exported environment variable, then run the wrapper's login command. Never put the PAT in argv.
3. For local decrypt/aead corruption, move the existing session directory to a timestamped sibling backup, recreate it with mode `0700`, and retry login.
4. Apply mode `0700` to state directories and `0600` to state files.
5. Verify vault listing and one permitted item operation before restarting dependent services.
6. Run the durable watchdog and require silent success. Do not depend on add-on system-service paths that disappear across container restarts.
7. Remove the corrupt-session backup only after the replacement session and dependent SSH agent are verified.

Always set a short, specific `PROTON_PASS_AGENT_REASON`. When the user says they approved after a timeout, reissue the operation; delayed phone approval is not refusal.

## Scoped SSH agent for Git operations

When a headless host needs Git SSH authentication, start the CLI's native daemon through the scoped wrapper instead of exporting a private key or falling back to an expired HTTPS token:

```bash
PROTON_PASS_AGENT_REASON="Authenticate Git remote" proton-pass-agent ssh-agent daemon start \
  --socket-path "<ssh-agent-socket>" \
  --vault-name "<scoped-vault>" \
  --pid-file "<ssh-agent-pid-file>" \
  --log-file "<ssh-agent-log-file>"
```

The first status check can briefly report `degraded` while keys are loading. Wait for the socket with a bounded retry, require `ssh-agent daemon status` to report `running`, then verify identities with `SSH_AUTH_SOCK="<ssh-agent-socket>" ssh-add -l`. For a new Git host, compare the scanned host-key fingerprint with the provider's official documentation before adding a scoped `known_hosts` entry. Test `ssh -T` before changing the remote and pushing. Keep the socket, PID, log, vault, and remote values in host-local configuration or the private context, not in this skill.
