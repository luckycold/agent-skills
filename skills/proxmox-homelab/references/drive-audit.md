# Drive and port audit (read-only)

Use when asked which disks are failing, too slow, or worth keeping, or how many SATA/M.2/PCIe ports are free. Never benchmark-write for this; reuse earlier capped results (`fio-chunk-test.sh`) where they exist.

## Collect

1. Run `scripts/drive-inventory.sh` on each host over SSH (copy to `/tmp`, run, delete). Keep the output private: it can still contain serials in zpool by-id names. For USB-bridged boot disks add `smartctl -x -d sat /dev/sdX`.
2. Board: `dmidecode -t baseboard` gives the model. **`dmidecode -t slot` "Current Usage" is unreliable on consumer boards** (ASUS reports every slot Available); decide occupancy from `lspci -tv` (a CPU root port with no child, or no CPU root port at all, means the x16 slots are empty).
3. Link speeds: SATA from `/sys/class/ata_link/*/sata_spd` and smartctl "SATA Version ... (current: …)"; NVMe from `/sys/class/nvme/nvmeN/device/current_link_{speed,width}` or `lspci -vv` LnkSta ("downgraded" just means a Gen4 drive in a Gen3 slot).
4. Map disks to ports with `readlink -f /sys/block/sdX/device` (ataN and the PCI controller), and NVMe to root ports. Add-in SATA/USB cards show up as extra controllers (e.g. ASM1062, uPD720201) on chipset downstream ports.
5. Look up the board manual for port counts and sharing rules, and each drive's spec sheet (seq R/W, HDD sustained rate, post-cache write for QLC/DRAM-less). Cite URLs.

## Classify

- **FAILING**: SSD reported uncorrectable > 0 with reallocated blocks growing, NVMe media errors > 0 or critical warning, HDD pending/offline-uncorrectable growing. Replace now.
- **WATCH**: HDD > ~6 years or any pending sector, SSD/NVMe wear > ~40% or bad blocks, recertified/white-label drives with reset hours, drives running near their max temperature, USB-attached boot disks.
- **TOO SLOW**: SMR (WD Blue EZAZ/EZRZ, etc.), QLC (Crucial P3/P3 Plus, Samsung QVO), SATA II-only disks, anything behind a PCIe Gen2 x1 card when it is a pool's bottleneck.
- **GOOD**: everything else.
- Benign: NVMe "Error Information Log Entries" alone, HDD Seagate raw read/seek error rates, a few UDMA CRC errors (cable), a single CRC on an SSD.

## Gotchas

- Mirrors of unequal disks waste the larger disk's extra space (check partition size in `lsblk`, not the disk size).
- Intel Z370-class boards: an M.2 socket in SATA mode disables one or two SATA ports. AM5 ASRock B850 boards: using the chipset M.2_3 disables PCIE3. Always check the manual's footnotes.
- Chipset-attached M.2/SATA share the chipset uplink (DMI 3.0 ≈ 3.9 GB/s on Intel 200/300 series).
- A drive's SMART "PASSED" means little; read the raw counters.
- Write the report with a master table (Host, Drive, Size, Type, Interface, Rated R/W, Measured, Health, Status, Recommendation), a per-host ports table (total/used/free plus sharing notes), and a short replace-first list. Keep serials and private topology out of the skill; specifics belong in private context.
