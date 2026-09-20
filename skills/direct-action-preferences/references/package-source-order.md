# Package source order and AUR review

Use this whenever software needs to be installed on Luke's Arch/Omarchy machines.

## Search order

1. Official `core` / `extra` / `multilib` / `omarchy` repos (`omarchy pkg add` / `pacman`).
2. Flatpak.
3. AUR **prebuilt** packages only (`*-bin` or a PKGBUILD that installs an official upstream binary and checksum). Never compile an AUR source package.
4. mise.
5. The official upstream prebuilt binary.

**Exception:** if the tool is high-churn and Luke wants it kept current, mise comes first.

If AUR only offers a source build, skip it and continue to the next step.

## Required AUR review

Complete this **before** `yay`, `makepkg`, or `omarchy pkg aur add`. Write the findings in the session, then install only if the review is clean.

- **Need:** confirm pacman and Flatpak have no package.
- **Identity:** upstream URL, AUR maintainer, votes, last update, out-of-date or orphaned flags. Prefer packages maintained by the upstream author or a known Arch Trusted User. Skip orphaned or flagged-out-of-date packages when a maintained sibling exists.
- **PKGBUILD sources:** every `source=` URL must be the official upstream, a signed GitHub release, or another first-party artifact. Reject random file hosts, shortened URLs, and `curl | sh` installers.
- **Build and install actions:** read `prepare`, `build`, `package`, `install`, and any `.install` script. Reject unexpected network calls, writes outside `$pkgdir`, `chmod 4755`, raw binary blobs, encoded payloads, and the 2026 AUR campaign markers (`npm install atomic-lockfile`, `bun install js-digest`, `lockfile-js`).
- **Binary packages:** a `*-bin` PKGBUILD should only install an official upstream binary and verify a published checksum or signature.
- **Reputation:** search for malware, hijack, or compromised-maintainer reports for this exact package name. An old unused name that recently changed maintainer or source is a stop.

If anything is unclear, do not install. Report the concern instead.
