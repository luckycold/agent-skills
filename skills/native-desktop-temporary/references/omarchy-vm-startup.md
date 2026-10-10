# Persistent Omarchy VM startup checks

Inspect the imported image's firmware, partitions, bootloader, kernel hooks and
root filesystem before treating an initial boot as proof of persistence.

A Cua Omarchy image booted through a minimal GRUB entry, while the supported
Omarchy update installed Limine kernel hooks. Updating removed the kernel path
the old GRUB entry referenced. The installed kernel could be booted manually
through the VM console with its matching initramfs; this allowed native repair.

Where Limine is already the maintained kernel-update route, use its documented
BIOS or UEFI deployment procedure for the guest's actual firmware. For BIOS/GPT,
verify the existing BIOS boot partition, deploy the packaged limine-bios.sys on
the boot partition, and run the native bios-install command with the correct
guest disk and partition index. Preserve the old configuration and uninstall
data. Do not apply these commands to the host's boot disk.

Read /etc/limine-entry-tool.conf and its drop-ins. An Omarchy command-line
override can take precedence over /etc/kernel/cmdline. Configure the actual
root device and console through the native /etc/default/limine
KERNEL_CMDLINE[default] setting, preserving required existing parameters.
Regenerate with the maintained limine-mkinitcpio command and verify every
generated entry contains the correct root device before restarting.
The command's --help argument was not a read-only help path in the tested
package; it performed a build. Inspect the package's documentation first.

Test unattended boot, guest-agent recovery, strict SSH, graphical startup,
keyring unlock and packaged agent services. Retain image recovery options until
these checks pass. If the guest SSH key changes, attest both its current address
and public key through the trusted hypervisor guest agent before replacing a
known_hosts entry; never disable host-key verification.

A BIOS deployment also needs its native bootloader deployment procedure after
a bootloader package upgrade. Kernel-entry hooks alone do not establish that
the BIOS bootloader payload was updated. Do not silently introduce a custom
package hook or boot service.

Primary references:
- [Limine usage](https://github.com/Limine-Bootloader/Limine/blob/v12.x/USAGE.md)
- [Arch Limine guide](https://wiki.archlinux.org/title/Limine)
- [Arch mkinitcpio guide](https://wiki.archlinux.org/title/Mkinitcpio)

## Central MCP broker lifecycle

A keepalive MCP broker spawned from an agent service can inherit that service's
cgroup. Restarting the service then kills the broker and leaves owner metadata.
Inspect the actual broker PID, cgroup and daemon namespace; a healthy main
service is not proof that its MCP lifecycle is healthy.

Use MCPorter's native MCPORTER_DAEMON_DIR setting in the user runtime directory
for reboot-scoped metadata. Keep it consistent across desktop, service and
client launches. Codex env_vars is an inherited-variable whitelist; it cannot
supply a variable that an earlier launcher has already removed. An additional
client can therefore create a competing broker in the default namespace.

Where mise already manages the tools, a client's supported MCP command can be
mise exec -- <central-bridge-path>. Native mise conf.d [env] settings then apply
at launch even when the parent filters its environment. Preserve one central
bridge and host-local overrides rather than duplicating upstream servers.
Keep scoped-agent flags in the actual shell startup configuration as well.
Validate native client parsing and Stow before relying on the override.

For an existing packaged user service, its ExecStartPre can use systemd-run
--user --scope --quiet --collect followed by mise exec -- mcporter daemon start.
The native scope places the broker outside the service's cgroup. Verify that a
warm service restart reuses the broker and that an unattended VM reboot creates
one runtime broker without a competing default owner. Do not introduce a custom
broker service or wrapper when these maintained facilities fit.

Stop a broker through its native interface and wait for its PID to retire before
archiving stale owner metadata. Never use stale-file removal to bypass an active
owner. Moving retired metadata from runtime tmpfs to a home-directory backup
can cross filesystems; use a file move that supports that boundary. Socket files
are retired separately only after their owner and transport are gone.

## Native OAuth outside a keepalive connection

Interactive OAuth can be rejected by a keepalive runtime even when the server
configuration is correct. Inspect the installed MCPorter version and native
lifecycle implementation. The verified release supports a process-local
MCPORTER_DISABLE_KEEPALIVE=<server-name> override for its auth command. Use that
one-time setting rather than removing the server lifecycle from shared config.

Run native mcporter auth <server-name> --no-browser in a durable terminal, with
private output, and open its fresh authorization URL in the browser on the same
host as the loopback callback. Do not print OAuth state, callback codes or URLs
containing them. A timed-out auth process requires a new native flow even when
the browser has since authenticated; reuse the browser session, not the expired
callback. Verify consent account and requested application before authorizing.

Require native auth exit success, selected-server tool discovery and a harmless
authenticated identity read. Then test cached authorization after a restart.
Keep native token storage and remove only completed temporary challenge logs.
Do not widen password-manager vault scopes to compensate for a stale credential.
