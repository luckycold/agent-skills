# Package source order and AUR review

Use this whenever software needs to be installed on Luke's Arch/Omarchy machines.

## Search order

1. Official `core` / `extra` / `multilib` / `omarchy` repos (`omarchy pkg add` / `pacman`).
2. Flatpak.
3. AUR **prebuilt** packages only (`*-bin` or a PKGBUILD that installs an official upstream binary and checksum). Never compile an AUR source package.
4. Official AppImage.
5. mise, when it can install a prebuilt (for example `github:owner/repo`). Prefer this over copying a binary into `~/.local/bin`.
6. A hand-placed official upstream binary, only if mise cannot install it.

**Exception:** if the tool is high-churn and Luke wants it kept current, mise comes first.

If AUR only offers a source build, skip it and continue to the next step. Use mise rather than compiling.

Omarchy 4 ships an ALPM hook (`00-omarchy-update-guard.hook`) that aborts a direct `pacman -Syu` / `--sync --sysupgrade`. Run system upgrades through `omarchy update`; plain installs are not blocked. `OMARCHY_ALLOW_DIRECT_PACMAN=1` bypasses the guard; do not use it without Luke.

## Python command-line applications

When the upstream Linux distribution is a Python package, check mise's built-in `pypi:` backend even if `mise registry` has no short name. `mise use -g pypi:<distribution>@latest` manages an isolated environment through uv when available. See the [official backend documentation](https://mise.jdx.dev/dev-tools/backends/pypi.html).

Check the interpreter actually used: older mise versions may accept the per-tool `python` option without applying it. The documented `uvx_args = "--python 3.12"` form can select a compatible interpreter for version-only installs; verify the installed environment and command before removing any prior installation.

Verify the installed application version against upstream. An unconstrained `uv tool install --no-build` can silently resolve an ancient application release when a current dependency has no wheel. Pin the intended application version while diagnosing this; distinguish packaging a pure Python dependency from compiling native code.

## Required AUR review

Complete this **before** `yay`, `makepkg`, or `omarchy pkg aur add`. Write the findings in the session, then install only if the review is clean.

- **Need:** confirm pacman and Flatpak have no package.
- **Identity:** upstream URL, AUR maintainer, votes, last update, out-of-date or orphaned flags. Prefer packages maintained by the upstream author or a known Arch Trusted User. Skip orphaned or flagged-out-of-date packages when a maintained sibling exists.
- **PKGBUILD sources:** every `source=` URL must be the official upstream, a signed GitHub release, or another first-party artifact. Reject random file hosts, shortened URLs, and `curl | sh` installers.
- **Build and install actions:** read `prepare`, `build`, `package`, `install`, and any `.install` script. Reject unexpected network calls, writes outside `$pkgdir`, `chmod 4755`, raw binary blobs, encoded payloads, and the 2026 AUR campaign markers (`npm install atomic-lockfile`, `bun install js-digest`, `lockfile-js`).
- **Binary packages:** a `*-bin` PKGBUILD should only install an official upstream binary and verify a published checksum or signature.
- **Reputation:** search for malware, hijack, or compromised-maintainer reports for this exact package name. An old unused name that recently changed maintainer or source is a stop.

If anything is unclear, do not install. Report the concern instead.

## Installed AUR package no longer updates

Check the installed name with `pacman -Qi` and query the AUR RPC for that exact name before assuming the updater is broken. A deleted or merged package can remain installed indefinitely; use AUR merge/deletion records and the upstream stable download to identify a maintained successor, then complete the review above.

Preserve application data and back it up after the app has exited. Prefer a package-manager replacement transaction over deleting installation files manually. Omarchy's `omarchy pkg aur add` uses `--noconfirm`, which can reject a conflicting old package because removal defaults to No. If it has already built the reviewed successor, install that exact cached package with interactive `pacman -U` and approve only the expected replacement. Verify package integrity, the app version, and a successful desktop launch; confirm that Omarchy's AUR updater includes the new package.
