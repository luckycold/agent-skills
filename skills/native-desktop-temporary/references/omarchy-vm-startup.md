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
