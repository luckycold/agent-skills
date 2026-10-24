# Diagnosing silent node hangs (journal just stops)

Use when a Proxmox node freezes with no panic in the journal and needs a power cycle. Read-only first; every change below needs Luke's OK or a standing rule.

## 1. Build the crash timeline

- `journalctl --list-boots`, then for each boot `journalctl -b <n> -n 5 -o short-iso`. A boot that ends in `Journal stopped` was clean; anything else (cron, smartd, ssh lines) was an unclean stop.
- Note idle vs load, uptime before each stop, kernel (`journalctl -b <n> -k | grep -m1 'Linux version'`), BIOS (`grep -m1 'BIOS '` on the same output) and microcode (`grep -m1 'microcode:'`). This shows whether a BIOS flash or kernel update changed anything.
- Cross-check with the cluster side: on a peer node, corosync `link: host: N link: 0 is down` gives the real freeze time (the journal on the dead node can lag by minutes). If corosync also died, the whole box stopped. A dead root disk alone would leave corosync and ping running.

## 2. Look for evidence that did survive

- **pstore**: `/var/lib/systemd/pstore/<epoch>/` holds oopses and panics saved to EFI variables (`efi_pstore`). Check it before anything else; the journal often misses the final oops. `date -d @<epoch>` gives the time.
- Kernel warnings across boots: `for b in $(seq -N 0); do journalctl -b $b -k -p warning; done | sort | uniq -c`. Look for soft/hard lockups, `smp_call_function_many_cond` (a CPU stopped answering IPIs), MCE/`[Hardware Error]`, AER, NVMe timeouts and NIC resets.
- Read the faulting instruction in an oops. A callee-saved register (r12–r15, rbx, rbp) holding garbage right after an idle call (`do_idle`, `cpuidle_enter`, `acpi_idle_enter`) means the CPU lost state on idle exit. That points to hardware, firmware or power, not a kernel logic bug.

## 3. Hardware and firmware checks (read-only)

- `dmidecode -t bios` vs the vendor BIOS page; `grep microcode /proc/cpuinfo` vs the newest patch in `/lib/firmware/amd-ucode/` (the BIOS copy is often newer for client CPUs, which is fine).
- Idle states: `for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do echo $(cat $s/name $s/desc $s/disable); done` plus `cat /sys/devices/system/cpu/cpuidle/current_driver`.
- Temperatures from `/sys/class/hwmon/*/temp*_input` (works without lm-sensors). PCIe ASPM (`lspci -vvv | grep ASPM`), GPU runtime PM (`/sys/bus/pci/devices/<gpu>/power/runtime_status`), NVMe APST (`nvme get-feature /dev/nvme0 -f 0x0c -H`).
- Hardware watchdog: `modprobe sp5100_tco` (AMD FCH) or `iTCO_wdt` (Intel) and check `dmesg`. Loading it does not arm it. Proxmox blacklists these modules for autoload only, so a named modprobe still works.

## 4. Zen 1/2 idle freezes

- The usual cause is package C6 at very low current. The best fix is the BIOS setting **Power Supply Idle Control = Typical Current Idle**. Some boards hide it.
- Disabling ACPI C2 (CC6) through cpuidle sysfs is not enough if the freezes continue: the remaining C1 still uses MWAIT. Next step: `processor.max_cstate=1 idle=nomwait` on the kernel line (C1 becomes HLT, and C6 is blocked from early boot rather than from a late systemd unit). Verify with the cpuidle loop above: `C1 ACPI HLT`.
- A BIOS update alone is not proof of a fix. Count only freezes that happen after the change and that you verified (see step 1).

## 5. Make the next hang leave evidence and recover by itself

- `/etc/sysctl.d/`: `kernel.panic=10`, `kernel.softlockup_panic=1`, `kernel.hardlockup_panic=1`, `kernel.panic_on_oops=1`, `kernel.*lockup_all_cpu_backtrace=1`. The panic lands in pstore and the node reboots. Leave `hung_task_panic` off when the node uses NFS, iSCSI or NVMe-TCP.
- Hardware watchdog through Proxmox's own mux: `WATCHDOG_MODULE=sp5100_tco` (or `iTCO_wdt`) in `/etc/default/pve-ha-manager`, then reboot. `/sys/class/watchdog/watchdog0/identity` should then name the hardware timer, with timeout 10 and state active. A hard hang then resets the board in about 10 s.
- netconsole does **not** work on a Proxmox bridge that has VM firewall ports (`fwpr*` veths do not support netpoll), and a bridge port is refused as a "slave device". Do not force it: a netpoll-enabled bridge can refuse new guest ports. Ship the journal off-box instead (rsyslog/systemd-journal-upload, or a minimal `journalctl -f | socat` stream to a peer).
- Do it all in one planned reboot. Shut guests down cleanly first, check `grub-editenv list` for a leftover `next_entry` (memtest), then verify the cmdline, idle states, watchdog identity, sysctls, quorum and guest autostart.
