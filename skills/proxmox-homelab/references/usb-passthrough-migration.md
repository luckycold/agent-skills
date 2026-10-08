# Moving a USB-passthrough VM between nodes

Use this for guests that own a USB radio or serial dongle (Thread/Zigbee/Z-Wave sticks, UPS cables). The disk move is usually trivial; the USB device, host memory, and the guest's drivers are what break.

## Prep (no downtime)

1. Read `qm config <vmid>` on the source node: `usbN: host=<bus>-<port>` is port-bound and cannot follow the VM; `host=<vid>:<pid>` or `mapping=<name>` can.
2. Get the ID with `lsusb` on the source, and check the target has **no other device with the same vid:pid** (`lsusb -d <vid>:<pid>`), otherwise ID matching is ambiguous.
3. Check `/etc/pve/mapping/usb.cfg` (or `pvesh get /cluster/mapping/usb`). Add the source node to an existing mapping while preserving every existing `map` entry and field, using the digest to avoid races:
   `pvesh set /cluster/mapping/usb/<name> --digest <digest> --map id=<vid>:<pid>,node=<a> --map id=<vid>:<pid>,node=<b> ...`
   Keeping the source node in the mapping keeps rollback a plain migrate back.
4. Do **not** change `usbN` on the running VM: default `hotplug` includes `usb`, so `qm set` replugs the device live (it is not a pending change).
5. Storage: shared disks plus cloud-init snippets on shared storage make an offline migrate a config move (seconds). Check no snapshots, replication jobs, or HA resources pin the VM.
6. Target host RAM: with ZFS and no swap, `MemAvailable` can be tiny because ARC defaults to ~all RAM. Cap ARC before adding guests (see below).
7. Guest drivers: confirm the module the device needs is available for the kernel the guest will **boot** next, not just the one running now: `modinfo -n <module>` and `ls /lib/modules`. Ubuntu cloud images (`linux-image-virtual`) ship USB-serial drivers such as `cp210x` only in `linux-modules-extra-<kver>`; unattended kernel upgrades do not pull that package, so the first reboot after an upgrade silently loses the device.

## Cutover

1. `qm shutdown <vmid> --timeout 120 && qm wait <vmid>` on the source.
2. `qm set <vmid> --usbN mapping=<name>` (fallback `host=<vid>:<pid>`, which then needs `qm migrate --force` because non-mapped local USB blocks migration).
3. Physically move the device; confirm with `lsusb -d <vid>:<pid>` on the target.
4. `qm migrate <vmid> <target>` from the source (offline; mapped devices are allowed when the target has a mapping entry).
5. `qm start <vmid>` on the target. Verify: `echo 'info usb' | qm monitor <vmid>`, the guest's udev symlink and service, the app's own health/state, and the IP (same MAC keeps the DHCP lease).
6. If the guest sees the USB device (`lsusb` in guest) but no `/dev/ttyUSB*`, the driver is missing (step 7 above): install the matching `linux-modules-extra-$(uname -r)`, `modprobe <module>`, `udevadm trigger`. No reboot needed.
7. Update the VM description if it mentions a port.

## ZFS ARC cap

- Live: `echo <bytes> > /sys/module/zfs/parameters/zfs_arc_max` (ARC shrinks within seconds; `0` = default).
- Persistent: `options zfs zfs_arc_max=<bytes>` in `/etc/modprobe.d/zfs.conf` (check for and keep existing options first), then `update-initramfs -u -k $(uname -r)` and confirm with `lsinitramfs /boot/initrd.img-$(uname -r) | grep zfs.conf`. Keep a copy of the old initrd for rollback.
- Check: `size` and `c` in `/proc/spl/kstat/zfs/arcstats`, and `MemAvailable`.
