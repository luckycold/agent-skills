---
name: temporary-support-watcher-cleanup
description: Inspect and clean up temporary personal support-ticket watchers, private notification alerts, scheduler jobs, and copied credentials after approval arrives, monitoring expires, or the user asks to stop. Use for watcher cleanup or to verify that an earlier claimed watcher actually runs.
author: Luke
disable-model-invocation: true
---

# Temporary Support Watcher Cleanup

Keep cleanup local to the requesting user's monitor. Never change a shared support workflow, another person's job, or customer machine state.

## Establish ownership and current state

1. Read the requested ticket through its configured connector. If the awaited response already exists, notify the user through the authorized personal destination before doing further setup. Quote the response and its timestamp; do not expand its permission scope.
2. Identify the monitor's exact scheduler/job ID, account or UID, process identity, and artifact paths from its creation record. Keep live ticket identifiers and notification destinations in private runtime state, never in this skill.
3. Inspect the named job and its most recent successful ticket-read timestamp. A running notification test proves delivery only. A background tool-cell ID can disappear between turns and does not establish persistent monitoring.
4. If no job was created, report that clearly. Do not install a new watcher after the awaited event has already occurred.

## Stop only the owned monitor

For a personal systemd monitor, inspect the exact unit first:

```bash
systemctl --user show "$WATCHER_UNIT" \
  -p ActiveState -p MainPID -p Transient -p FragmentPath
```

Do not print `ExecStart` if an earlier implementation put credentials in its command line. Correct that separately without exposing them.

- Stop the exact owned timer first, if present, then its service. Use `--user`; do not operate on system services for a personal watcher.
- For a transient unit created with `--collect`, stopping it lets systemd unload it. Verify inactive/not-found state and that its recorded process has exited; do not create a permanent unit file to clean up a transient service.
- For installed units, disable only the exact owned timer/service, remove only the recorded files, and run `systemctl --user daemon-reload` afterward.
- For a standalone process, verify its UID, executable, and recorded start identity before terminating it. Never use broad `pkill`, `killall`, or name-only matching across support processes.
- For a hosted schedule, use its native API to disable/delete the exact personal job. Mark a fallback personal reminder complete when it is no longer needed.
- For an active tool cell, use the tool's stop/termination mechanism. If the cell is already gone, acknowledge that monitoring stopped; do not claim it kept running.

## Remove only temporary artifacts

1. Delete copied API credentials from the monitor's own private directory. Never revoke a shared source token or remove the user's existing login cache.
2. Remove the owned script, PID/lock files, and deduplication state when no longer needed. Preserve evidence the user still needs for the support investigation; explain any intentionally retained files.
3. Preserve the existing notification app configuration, subscriptions, and tokens. Do not remove a shared webhook or alter team-wide workflows.
4. Confirm the monitor is inactive, its process is gone, no owned timer remains, and its temporary credentials are absent. Do not claim secure erasure on SSDs.

## Requirements for any replacement

- Ask about a maintained package before writing custom glue unless the user has already authorized that implementation.
- When the user requests another watcher after a reply, first verify the old watcher stopped and its copied credentials were removed. Read the full current thread and record the latest existing reply or acknowledgement as the new baseline, so the replacement cannot immediately alert on the already-seen response. A new request for the same approved temporary implementation does not require repeating the package question.
- Anchor a follow-up reminder to the user's requested interval or the awaited party's explicit ETA. Calculate from the relevant message timestamp, announce the resulting deadline, and describe any later reply as an update unless its content confirms completion.
- Use read-only ticket requests and the user's explicitly authorized notification destination. Alerts are not permission to reboot, test, or modify customer machines.
- Record exact ownership, cleanup paths, deadline, and scheduler identity privately. Bound the lifetime and arrange credential deletion on stop/expiry.
- Verify an independent scheduler/process plus a successful scheduled read before calling it persistent. State workstation/network dependencies.
- Test notification delivery separately. Priority 5 is ntfy's maximum; audible behavior depends on the receiving device. Never imply an alert test is customer approval.

## Self-maintenance

After verified corrections, follow [personal-skill-maintenance](../personal-skill-maintenance/SKILL.md). Keep this skill portable and free of credentials, personal topic names, private endpoints, and live incident details.
