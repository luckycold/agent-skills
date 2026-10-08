#!/bin/bash
# Usage: bash drive-inventory.sh > host-drives.txt   (run as root on a PVE/TrueNAS/Debian host)
# Read-only drive + port inventory: board/slots (dmidecode), PCIe tree and link speeds, SATA links,
# lsblk/zpool/LVM, smartctl -x per disk, NVMe id-ctrl + link. Filters serial/WWN/EUI lines, but
# zpool by-id names and some fields can still carry serials: keep the output private.
# USB-bridged disks need `smartctl -x -d sat /dev/sdX` separately.
export LC_ALL=C
echo "### HOST $(hostname) $(date -Is)"
echo "### DMI"; dmidecode -t system -t baseboard 2>/dev/null | grep -vE "Serial Number|UUID|Asset Tag" 
echo "### SLOTS"; dmidecode -t slot 2>/dev/null | grep -E "Designation|Type:|Current Usage|Bus Address|Length"
echo "### CPU"; lscpu | grep -E "Model name|^CPU\(s\)"
echo "### LSPCI"; lspci -nn
echo "### LSPCI-STORAGE-LINK"
for d in $(lspci -D | grep -iE "SATA|NVMe|Non-Volatile|RAID|SAS|SCSI|storage" | cut -d' ' -f1); do echo "== $d $(lspci -s $d)"; lspci -vv -s $d 2>/dev/null | grep -E "LnkCap:|LnkSta:" ; echo "parent: $(readlink -f /sys/bus/pci/devices/$d/.. | xargs basename)"; done
echo "### ATA PORTS"; for p in /sys/class/ata_port/*; do n=$(basename $p); printf "%s " $n; ls -d $(readlink -f $p/device)/../* 2>/dev/null | head -0; readlink -f $p/device | sed 's#/ata[0-9]*$##' | xargs basename; done
echo "### ATA LINKS"; for l in /sys/class/ata_link/*; do printf "%s sata_spd=%s\n" $(basename $l) "$(cat $l/sata_spd 2>/dev/null)"; done
echo "### dmesg SATA link"; dmesg 2>/dev/null | grep -E "SATA link (up|down)" | sed 's/^\[[^]]*\] //' | sort -u
echo "### LSBLK"; lsblk -d -o NAME,SIZE,ROTA,TRAN,MODEL,HCTL,TYPE -e 7,1,251,252 2>/dev/null | grep -v zd
echo "### LSBLK-FULL"; lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT -e 7,1 2>/dev/null | grep -v "^zd"
echo "### ZPOOL"; zpool status 2>/dev/null | grep -vE "^\s*$" ; zpool list 2>/dev/null
echo "### PVS"; pvs 2>/dev/null; vgs 2>/dev/null
for d in /dev/sd? /dev/nvme?n1; do [ -e "$d" ] || continue
  echo "### SMART $d"; smartctl -x $d 2>&1 | grep -viE "serial|^LU WWN|^WWN|IEEE|EUI|NGUID|Device Identifier"
  echo "### SYSFS $d"; readlink -f /sys/block/$(basename $d)/device 
done
for c in /dev/nvme?; do [ -e "$c" ] || continue; echo "### NVME-ID $c"; nvme id-ctrl $c 2>/dev/null | grep -E "^(mn|fr|tnvmcap|mdts|hmpre|hmmin|wctemp|cctemp|ver|nn) "; echo "link: $(cat /sys/class/nvme/$(basename $c)/device/current_link_speed 2>/dev/null) x$(cat /sys/class/nvme/$(basename $c)/device/current_link_width 2>/dev/null) / max $(cat /sys/class/nvme/$(basename $c)/device/max_link_speed 2>/dev/null) x$(cat /sys/class/nvme/$(basename $c)/device/max_link_width 2>/dev/null) transport=$(cat /sys/class/nvme/$(basename $c)/transport 2>/dev/null)"; done
echo "### USB-STORAGE"; lsusb 2>/dev/null; lsusb -t 2>/dev/null | grep -iE "storage|uas"
echo "### END"
