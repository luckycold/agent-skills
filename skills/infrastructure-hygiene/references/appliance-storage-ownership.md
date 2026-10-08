# Preparing appliance storage on another Linux host

_Moved verbatim from `SKILL.md` on 2026-10-08 during the size refactor; the skill keeps a short summary that links here._

After using a desktop disk utility to take ownership of an appliance filesystem for staging files, restore its filesystem root to the owner expected by the appliance before booting it. For a root-managed Linux appliance this is normally `root:root`; inspect its image and shipped configuration first. Change only the affected directory rather than recursively rewriting games or user data. A host user owning the filesystem root can cause systemd-tmpfiles to reject transitions into root-owned subdirectories, leaving native overlay work directories missing and emulator or service mounts unavailable.

When logs show `Detected unsafe path transition` followed by missing overlay work directories, verify directory ownership, restore the expected owner, rerun the shipped tmpfiles configuration, and start the shipped failed mount units. Check that the required files are accessible, then verify after reboot when the user is out of any active workload. Preserve current saves and settings; use the emulator's native no-save mode for diagnostic runs. Prefer this native initialization repair over custom startup scripts or replacement mount units.
