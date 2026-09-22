---
name: omarchy-dual-boot-secure-boot
description: >
  Dual Omarchy personal/work boot on one laptop: Limine GUID chainload,
  black-and-white Limine/SDDM theming, sbctl key split, firmware db trust,
  SKIP_UEFI on the non-default OS, Clevis PCR 7 after TPM unlock, and
  installing third-party Omarchy shell plugins onto a mounted peer OS home.
  Triggers: work OS external drive, personal internal drive, Limine menu,
  Secure Boot, sbctl enroll-keys, config checksum panic, BootOrder, BootNext,
  SDDM autologin after Clevis, where-is-my-sddm-theme, omarchy plugins on the
  other drive, sync plugins personal to work, automatic plugin sync.
author: Luke
category: desktop
---

# Dual Omarchy Secure Boot

Two Omarchy installs, two ESPs, two sbctl keysets. Firmware boots the
personal disk. Work is a Limine menu chainload, not a firmware default.

Dotfiles live in the `dual-omarchy-boot` bootstrap plus `root/` SDDM files.
Apply the matching role from that repo; do not invent a second boot chain.

## Hard rules

- Personal owns firmware PK/KEK. Only Personal may write firmware `db`.
- Never enroll Work PK/KEK. Never run `sbctl enroll-keys --yes-this-might-brick-my-machine`.
- Copy only the peer **public** `db.pem`. Never copy `.key` files.
- Each OS signs only its own ESP. Do not rewrite peer Limine/UKI binaries.
- Do not change `BootOrder` or set `BootNext` to pick an OS. Use the firmware
  boot menu or the Limine GUID chainload entry.
- Leave `SKIP_UEFI=yes` on Work so `limine-update` cannot create NVRAM entries.
- Keep each disk's LUKS passphrase slot. Clevis is an extra unlock path.
- Bind Clevis only after a successful Secure Boot boot on the intended path.
- PCR `7` measures Secure Boot policy and the `db` certificates that
  verified images, not image hashes. UKI rebuilds and `limine-update`
  signed with the same key do not break a PCR `7` bind.
- PCR `7` can differ between boots of the same entry when Thunderbolt
  dock/eGPU/enclosure option ROMs enumerate pre-boot and add a `db`
  authority event. Keep one Clevis PCR `7` slot per observed state
  instead of replacing a slot that only fails in the other state.
- Working policy is PCR `7`. Do not reintroduce PCR `1,7` unless Luke asks.
- Keep SDDM as a password prompt after TPM disk unlock. No autologin.
- Re-enroll `limine.conf` with that OS's `limine-update` / `limine-enroll-config`.
  Never hand-edit BLAKE2 hashes.

See [dual-os-sbctl-and-clevis.md](references/dual-os-sbctl-and-clevis.md)
for the apply sequence, firmware `db` enrollment, and recovery checks.

## Third-party shell plugins

Omarchy has no plugin lockfile. `omaplug` manages one live session. Do not
write a custom installer. Stow does not own `~/.config/omarchy/plugins/`.

When the peer OS home is mounted, install missing plugins with official
`omarchy plugin add`, or sync existing checkouts with Unison. Do not pass
`--enable` from the other OS, and do not copy `shell.json`. Details:
[peer-os-plugin-install.md](references/peer-os-plugin-install.md).

## Theme

Limine colors are not stored in the generated kernel entries. The bootstrap
installs `/etc/limine-theme.conf` and post-hook `87-limine-theme`, which
rewrites the header to black-and-white after every `limine-update`. SDDM uses
`where-is-my-sddm-theme` plus the stowed `theme.conf.user` overlay and the
late `zz-where-is-my-sddm.conf` drop-in.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical
package under `~/.agents/skills/` when a verified reusable correction, user
correction, or repeatable workflow would improve future runs. Make the
smallest evidence-backed edit, do not record secrets or transient state, and
do not infer a durable preference from one request. Follow the
`personal-skill-maintenance` skill for the full review and verification
workflow.
