# Dual-OS sbctl trust and Clevis

Generalized from the proven personal-drive setup. Keep hostnames, GUIDs,
fingerprints, PCR hashes, and device serials out of this file. Resolve exact
disk paths on the live machine.

## Roles

- **Personal**: internal ESP and root LUKS. Firmware default. Owns enrolled
  PK/KEK. Stores the Work public `db` certificate under
  `/var/lib/sbctl/keys/custom/db/`.
- **Work**: external ESP and root LUKS. `SKIP_UEFI=yes`. Signs only its ESP
  with its local keyset. Reaches Personal through a Limine `guid(...)` EFI
  chainload, not a Work-created NVRAM entry.

The working firmware path is the personal disk's own EFI Hard Drive /
`EFI/BOOT/BOOTX64.EFI` fallback. A named `Limine` NVRAM entry is optional
and must not be created or reordered on a proven install.

## Apply from the dotfiles clone

On Personal:

```bash
stow -t ~ common
stow -t ~ personal
sudo stow -t / root
sudo ./bootstrap/dual-omarchy-boot/apply.sh --role personal
sudo ./bootstrap/sddm-gnome-keyring/apply.sh
```

On Work:

```bash
stow -t ~ common
stow -t ~ work
init-env-secrets --all
sudo stow -t / root
sudo ./bootstrap/sddm-gnome-keyring/apply.sh
sudo ./bootstrap/dual-omarchy-boot/apply.sh --role work
```

Work needs the `where-is-my-sddm-theme-git` package so the stowed
`theme.conf.user` overlay has a theme directory.

Do **not** pass `--update-firmware-entries` or `--repair-peer` unless Luke
explicitly wants NVRAM edits or a peer-ESP rewrite. Those options exist for
recovery, not routine apply.

## Firmware db trust

1. On Work, copy only `/var/lib/sbctl/keys/db/db.pem` to removable storage
   or a path Personal can read. Do not copy `db.key`.
2. Boot Personal. Install that public cert as
   `/var/lib/sbctl/keys/custom/db/<peer>-db.pem`.
3. From Personal only. If Personal already owns firmware PK/KEK/`db` and
   the Work public cert is staged under `custom/db/`, append that cert
   instead of rebuilding the whole database:

```bash
sudo chattr -i /sys/firmware/efi/efivars/db-*
sudo sbctl enroll-keys --partial db --append --custom --ignore-immutable
sudo chattr +i /sys/firmware/efi/efivars/db-*
```

Use the fuller `--partial db --custom --microsoft --firmware-builtin`
form only when firmware `db` is missing vendor or Personal certs. If
firmware `db` is immutable, the verified extra steps are
`--ignore-immutable` and `chattr` on **db only**. Do not clear PK/KEK or
reset the TPM. Do not use `--yes-this-might-brick-my-machine`.

4. Confirm firmware `db` lists both custom certificates plus vendor/Microsoft
   builtins. `sbctl verify` on each OS should succeed for that OS's own
   Limine, fallback, and UKI paths. Export enrolled `db` certs and compare
   public fingerprints; `list-enrolled-keys` names can collide because both
   OS certs may be called `Database Key`.

Appending a peer `db` certificate changes PCR `7`. The next boot of either
OS will need the LUKS passphrase, then a new PCR `7` bind from inside that
OS. Do not rebind in the same session that wrote firmware `db`.

If an older peer-repair run left `/tmp/tmp.*` paths in Work's
`/var/lib/sbctl/files.json`, remove those stale entries with
`sbctl remove-file` on Work. Do not sign Personal files with Work keys.

## Clevis

1. Confirm identity: hostname, `/` LUKS, `/boot` ESP, Secure Boot enabled,
   no `BootNext`, and `sudo sbctl verify` clean for the live loaders.
2. Back up the LUKS header to a root-only path. Never commit it.
3. Keep the passphrase slot. Remove only confirmed-stale TPM slots.
4. Bind:

```bash
sudo clevis luks bind -d <LUKS_DEVICE> tpm2 '{"pcr_bank":"sha256","pcr_ids":"7"}'
```

5. Prove userspace unseal without printing the key, then prove a later
   reboot auto-unlocks. Live `clevis luks unlock` is not proof by itself.

`apply.sh`, mkinitcpio hooks, and `limine-update` rewrite and resign
Limine/UKI files. That does not change PCR `7` when the same `db`
certificate signs them; PCR `7` records policy variables and the
verifying certificates, not image hashes (PCR `4` does). Verified: a
UKI rebuild mid-session left PCR `7` identical.

PCR `7` is not stable across boots when Thunderbolt devices (dock,
eGPU, NVMe enclosure) are attached. Firmware logs one
`EV_EFI_VARIABLE_AUTHORITY` per distinct `db` certificate that verified
an image; pre-boot option ROMs add Microsoft UEFI CA entries whose
presence varies with enumeration timing. Two PCR `7` values recurred
across boots of the same Limine entry, and each single-slot rebind
landed on the other state. The kernel entry was not the cause.

Fix without glue: leave the existing slot and add a second PCR `7`
slot from a boot in the other state. The initramfs `clevis-luks-unlock`
tries every bound slot. Diagnose with:

```bash
sudo tpm2_pcrread sha256:7
sudo tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements \
  | grep -B2 -A12 'EV_EFI_VARIABLE_AUTHORITY'
```

Compare the authority count and subjects before deciding a slot is
stale. Remove a TPM slot only when its state has not recurred.

PCR `1` measures firmware boot variables. Creating, deleting, or reordering
`Boot####` entries, or setting `BootNext`, stale a PCR `1,7` slot. Hibernation
resume has also been observed to change PCR `1` on this hardware class while
leaving PCR `7` stable. Use PCR `7` unless Luke asks for the stricter bind.

## Recovery without breaking the peer

- Keep Secure Boot enabled unless firmware rejected a loader.
- Repair only the OS that failed. Leave the peer ESP binaries alone.
- Verify Personal files with Personal keys and Work files with Work keys.
- If Limine panics on a config checksum, boot that same OS and run its
  `limine-update` so enrollment and the theme hook run together.
- If TPM unlock fails after a boot-path change, unlock with the
  passphrase and rebind PCR `7` from inside that OS. If PCR `7`
  alternates between boots, add a slot rather than replace one. Do
  not "fix" it by changing `BootOrder`.

## Checks

```bash
sbctl status
sbctl verify
efibootmgr
grep -E 'SKIP_UEFI|FIND_BOOTLOADERS' /etc/default/limine
sed -n '1,25p' /boot/limine.conf
grep -E 'Current=|User=' /etc/sddm.conf.d/zz-where-is-my-sddm.conf
clevis luks list -d <LUKS_DEVICE>
```

Expect Secure Boot enabled, local loaders signed, Work `SKIP_UEFI=yes`,
black-and-white Limine header colors, SDDM theme `where_is_my_sddm_theme`
with empty autologin, and a passphrase slot still present.
