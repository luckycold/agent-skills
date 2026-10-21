# T3 memory-pressure recovery on a small Linux VM

A T3 environment can appear offline while its service and managed relay remain alive. Confirm the failure layer before restarting active agents.

1. Correlate client `EnvironmentSupervisor.connectionLost` timestamps with host reachability and the server service PID/restart count. Do not dump connection catalogs, process environments, or auth files: these can contain credentials.
2. On the guest inspect `free -h`, `swapon --show`, `/proc/pressure/memory`, `/proc/pressure/io`, and `vmstat 1 3`. Compare process RSS plus `VmSwap` from `/proc/<pid>/status`. Sustained memory stalls, full swap, and many blocked processes indicate memory exhaustion even without an OOM kill.
3. Identify newly opened browser renderers and other workload growth near the first disconnect. Prefer closing a confirmed heavy tab through native browser controls. If the server cannot operate those controls, verify the exact renderer PID and executable immediately before terminating only that renderer. Its tab will need reloading; avoid killing the browser or service indiscriminately.
4. Before increasing VM RAM, check hypervisor headroom and whether the running VM supports memory hotplug. Do not reboot the guest or shrink another guest merely to recover T3.
5. When the guest has only disk swap, the distro-packaged `zram-generator` can provide compressed swap through supported system configuration. Inspect existing zram and zswap first; avoid double compression. On Arch, install the official `zram-generator` package. A native configuration under `/etc/systemd/zram-generator.conf.d/` can use:

   ```ini
   [zram0]
   zram-size = ram
   compression-algorithm = zstd
   swap-priority = 100
   ```

   Preserve any existing configuration. Run `systemctl daemon-reload` and start `dev-zram0.swap`; retain lower-priority disk swap. Check `zramctl`, `swapon --show`, and `systemctl is-active dev-zram0.swap`. Do not run `swapoff` on full disk swap while RAM is exhausted. This provides capacity relief, not unlimited RAM; size it for the workload and verify actual compression and pressure.
6. Require falling memory/IO stalls and repeatable application responsiveness. A static HTTP 200 alone does not prove authenticated RPC or relay health. Verify a paired client can list threads and receive current state, and check that the original service PID is unchanged if no restart was required.
7. When authorized, notify affected sessions which tab was stopped, which persistent memory configuration changed, and that browser work may need a reload. Do not tell sessions a provider or authentication fix is needed solely because the host stalled.

[Upstream zram-generator documentation](https://github.com/systemd/zram-generator).
