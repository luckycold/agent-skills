# TPM unlocking across hibernation

Use for Linux LUKS/Clevis automatic disk unlocking that succeeds during normal boot but requests the encryption password during hibernation resume. Supplement the applicable desktop/distribution skill; do not modify vendor skills.

## Diagnose the policy before changing it

1. Inspect Secure Boot, the active kernel, initramfs unlock integration, and Clevis bindings. Discover the actual encrypted block device; do not infer it from a previous machine.
2. Establish whether the prompt occurs on a normal restart, hibernation wake-up, or both. Keep disk encryption, desktop login, and login-keyring prompts distinct.
3. Obtain the actual early-boot error. `Esys_Unseal(0x99D)` / `a policy check failed` identifies a TPM policy failure; it is not evidence of a missing TPM or missing unlock binary.
4. Compare measurements from a successful normal boot and after a hibernation wake-up, for example `sudo tpm2_pcrread sha256:1,7`. Keep raw PCR values and device identifiers out of durable skill documentation.
5. Check the actual boot image as well as the installed configuration. Successful unsealing in a running session, even with the image's binaries, does not establish that measurements match during early boot. PCR 7 records Secure Boot policy and the verifying `db` certificates, not image hashes, so UKI rebuilds signed with the same key do not break a PCR 7 bind. With Thunderbolt dock/eGPU/enclosure hardware, PCR 7 can alternate between boots as option-ROM `db` authority events come and go; keep one PCR 7 slot per observed state instead of chasing it with single-slot rebinds. Follow `omarchy-dual-boot-secure-boot`.

Observed on Framework AMD hardware: PCR 1 changed between normal boot and hibernation resume, while PCR 7 remained identical. A Clevis policy requiring `1,7` therefore failed during resume. Do not assume this applies to every machine; compare first.

## Replace only the incompatible binding

When the changing PCR 1 measurement is established and Secure Boot is enabled, a PCR 7 policy is a documented Clevis option:

```json
{"pcr_bank":"sha256","pcr_ids":"7"}
```

Explain the tradeoff: this retains binding to this TPM and its measured Secure Boot policy, but drops the additional firmware-configuration check from PCR 1. PCR 7 alone does not pin an exact kernel or complete boot chain. Do not silently remove PCR checks, use an empty policy, or present PCR 7 as equivalent to every stricter policy.

Replacement sequence:

1. Back up the LUKS header to a root-only location. Treat it as sensitive recovery material; never commit it.
2. Identify the working password/recovery slot and preserve it. Slot numbers must be discovered, not hardcoded.
3. Add the replacement binding in a free slot using `clevis luks bind`. Have the user enter the existing disk password directly into a visible terminal. Never ask for it in chat or place it in arguments/logs.
4. Validate by piping `clevis luks pass` directly to `cryptsetup open --test-passphrase --key-slot ... --key-file -`, with `pipefail` enabled. Never print the unsealed key.
5. Only after validation, remove the superseded TPM binding within the authorized cleanup scope. Re-list slots and tokens to confirm the password slot remains.
6. Test both normal boot and hibernation resume. Live validation is an intermediate result, not proof that either boot path is fixed.

Enrollment can fail with `Failed to import token from file` / `Error saving metadata to LUKS2 header` when obsolete bindings consume the JSON metadata area. Inspect metadata capacity and tokens; back up before removing confirmed obsolete bindings. Do not delete the recovery slot or repeatedly add duplicate bindings.

## Diagnose resume freezes separately

A restored lock-screen image with no input response does not establish a TPM problem. Inspect previous-boot kernel and `systemd-hibernate.service` logs. A hard resume hang can leave only the hibernation-entry record; absence of later logs does not prove that no image was written.

For a suspected device-resume ordering problem, `/sys/power/pm_async=0` serializes device power transitions. On the investigated Framework AMD system, one hibernate/resume cycle succeeded after this change, but a later cycle froze again. A single successful cycle is insufficient evidence of a fix. Treat serialization as a diagnostic workaround, not a reliable resolution. Check whether the pointer still moves or a virtual terminal can be reached during the freeze before concluding that the whole kernel is hung; a restored lock-screen image alone cannot distinguish a compositor/input failure from a device or kernel resume hang.

Apply to the current system and persist using a standard tmpfiles rule when appropriate:

```text
# /etc/tmpfiles.d/framework-pm-async.conf
w /sys/power/pm_async - - - - 0
```

Apply the specific file with `systemd-tmpfiles --create`, then read `/sys/power/pm_async` to confirm `0`. Entry/exit may be slower. To revert, remove the rule and restore the original value. Do not initiate a disruptive hibernation test without coordinating with the user and allowing work to be saved.

Early-boot diagnostics saved only under `/run` may be lost when the hibernated memory image is restored or after a forced reboot. A photograph of the pre-unlock error can be more useful than assuming the resumed session retains that log. Diagnostic hooks must never record plaintext unlock keys.

## Sources

- [Ubuntu: TPM-based LUKS decryption with Clevis](https://ubuntu.com/server/docs/how-to/security/tpm-backed-luks-decryption-with-clevis/) — PCR 7 binding and recovery-passphrase guidance; distribution integration differs.
- [Linux power sysfs ABI](https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux.git/+/master/Documentation/ABI/testing/sysfs-power) — `pm_async` semantics.
- [Framework hibernation resume report](https://community.frame.work/t/hibernate-resume-failures-on-framework-13-amd-ryzen-ai-300-krackan-a-b-tested-workaround-pm-async-0/83040) — first-hand workaround report with limitations; not a vendor guarantee.
