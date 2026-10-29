# Approved major-upgrade verification

Use only within an explicitly authorized upgrade plan. Read the current official Proxmox major-upgrade guide; do not treat this checklist as a replacement. Resolve exact targets from the task/private context.

## Before installation

- Identify a standalone target by address and interface configuration, not just hostname: unrelated hosts can share a name. Preserve explicit exclusions on cluster-node reboots.
- If an off-host backup is an upgrade gate, require the final exact file size and an independent checksum of the saved destination file matching the source. A streaming checksum is useful corroboration, not the independent saved-file check. Inspect an existing transfer before starting another.
- Save current network, APT and boot configuration, guest-config checksums, boot ID and package state under a dated root-owned directory. Do not print raw storage or notification configurations.
- Update the old release fully, verify its reboot, and remediate the official migration checker before changing release repositories. Review the simulated major upgrade, including removals and retained fallback kernels.
- Run long package operations in a packaged terminal multiplexer, with a durable log and exit-status file. Keep existing configuration files when the approved plan requires it. Do not use an SSH timeout as the lifetime limit for installation.

## After an interruption

- A terminal multiplexer survives a disconnected SSH client; it does not survive a host power-off. Inspect boot ID, uptime, existing processes/session, logs and the exit-status file before retrying. Never duplicate a running package operation.
- A GUI still showing the old version may be accurate if downloads were interrupted. Check `pveversion`, `/var/log/dpkg.log`, `dpkg --audit` and package holds. Distinguish an interrupted download from incomplete unpack/configuration rather than automatically running repair commands.
- An absent exit-status file is not proof of success. Abrupt journal termination or null bytes at the end of a log can corroborate an unclean stop but do not establish its hardware cause. Follow the task's stop/report instructions; resume only within applicable user direction.

## Before and after reboot

- Verify the new kernel/initramfs and boot-menu entry, required bootloader package, fallback kernels, package audit and unchanged network configuration.
- Re-enumerate every current guest before reboot; inventory can change while another actor works. If VM starts are forbidden, confirm stopped state and disabled/default-false onboot for every current VM. Check containers separately. An empty `pct list` can have no header; do not assume its line count is one.
- Post-upgrade service errors may reflect upgraded userspace awaiting the planned reboot. Inspect the actual failure, validate configuration where supported and retest after boot; do not hide errors or patch units without evidence.
- Confirm a changed boot ID and the intended new running kernel. Check Proxmox services, storage, guest state/configuration checksums, package audit/holds, time synchronization, failed units, web-UI HTTP response and the full migration checker.
- Honor a no-guest-start boundary even when passthrough verification is normally part of an upgrade guide. Report that runtime guest/passthrough checks were not performed.
- Save a final report with backup verification, exact final version/kernel, problems and recoveries, preserved fallbacks and validation limits. Disable temporary monitoring when finished or stopped.
