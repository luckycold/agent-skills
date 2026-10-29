---
name: direct-action-preferences
description: Luke's package-source order, the AUR malware review, Omarchy TPM/PCR 7 unlock, and the ask-before-custom-glue rule. Use when installing software, reviewing an AUR package, debugging Omarchy disk unlock or hibernation, or before writing a wrapper, helper, or unit.
author: Luke
category: agent-behavior
---

# Direct action preferences

Use this when installing software on Luke's machines, reviewing an AUR package, working on Omarchy TPM unlock or hibernation, or before writing custom glue.

## Ask before custom glue

Before writing a wrapper, helper binary, systemd unit, hook, or other bespoke tool, ask Luke whether a simpler maintained package can be installed instead. Do not ship the custom path first and mention the package later. Supported application configuration, including native command fields, is ordinary work. Do not turn a configuration limit into a locally maintained plugin fork without asking.

## Package sources

Use this order. Do not skip a higher option because a lower one is familiar.

1. Official distro or Omarchy repo packages (`omarchy pkg add` / `pacman`).
2. Flatpak.
3. AUR **prebuilt** packages only (`*-bin` or an official binary install), after the malware review in [package-source-order.md](references/package-source-order.md). Skip source-compile AUR packages.
4. Official AppImage.
5. mise, when it can install a prebuilt (for example the `github:` backend). This is preferred over a hand-placed binary.
6. A hand-placed official upstream binary, only if mise cannot install it.

**Exception:** if the tool is high-churn and Luke wants it kept current, mise comes first.

Do not run `yay` or `omarchy pkg aur add` until that review is written and the package is clearly not malicious. If the review is inconclusive, stop and tell Luke.

## Omarchy TPM unlock and hibernation

On the Omarchy laptop, do not change firmware keys, `BootOrder`, or `BootNext` to work around a boot or unlock problem. Re-enroll `limine.conf` with `limine-update` rather than hand-editing hashes. The working unlock policy is PCR 7. Any firmware `db` write changes PCR 7.

A successful live unlock does not prove resume-time unlocking. Distinguish normal boot from hibernation resume and compare the bound PCR measurements before replacing keys. See [TPM unlocking across hibernation](references/tpm-unlock-hibernation.md).

## Self-maintenance

This is a Luke-authored personal skill. After a verified correction, update this package with the smallest evidence-backed edit. Follow `personal-skill-maintenance`. Do not record secrets or infer a preference from one request.
