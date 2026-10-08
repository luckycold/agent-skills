#!/usr/bin/env bash
# Read-only Proxmox VE inventory. Run ON a PVE node as root:
#   ssh -o BatchMode=yes root@<pve-ip> 'bash -s' < pve-inventory.sh > inventory-raw.txt
# Makes no changes. Redacts storage-plugin secrets. Nested ssh/pct calls use -n / </dev/null.
set -u
sec() { printf '\n===== %s =====\n' "$*"; }
redact() { sed -E 's/((api_key|password|token|secret)[^ ]*)[ =].*/\1 [REDACTED]/I'; }

sec version;       pveversion -v | head -40; uname -r
sec cluster;       pvecm status 2>&1; pvecm nodes 2>&1
sec resources;     pvesh get /cluster/resources --output-format json 2>&1
sec storage;       pvesm status 2>&1; redact < /etc/pve/storage.cfg
sec zfs;           zpool list 2>&1; zpool status -x 2>&1; zpool status 2>&1 | grep -E 'pool:|state:|scan:|errors:'
sec disks;         lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL 2>&1
sec guests;        qm list 2>&1; pct list 2>&1
sec guest-configs
for f in /etc/pve/nodes/*/qemu-server/*.conf /etc/pve/nodes/*/lxc/*.conf; do
  [ -f "$f" ] || continue; echo "--- $f"
  sed -n '/^\[/q;p' "$f" | grep -vE '^(cipassword|sshkeys|smbios1|vmgenid)'
done
sec network;       cat /etc/network/interfaces; ip -br a; ip r; cat /proc/net/vlan/config 2>/dev/null
sec backup-jobs;   ls -la /etc/pve/jobs.cfg; cat /etc/pve/jobs.cfg; pvesh get /cluster/backup --output-format json 2>&1
sec not-backed-up; pvesh get /cluster/backup-info/not-backed-up --output-format json 2>&1
sec replication;   cat /etc/pve/replication.cfg 2>&1; pvesr status 2>&1
sec ha;            ha-manager status 2>&1
sec notifications; grep -viE 'secret|token|password|key' /etc/pve/notifications.cfg 2>&1
sec postfix;       journalctl --since -2d --no-pager 2>/dev/null | grep postfix | grep 'status=' | tail -5
sec failed;        systemctl --failed --no-legend
sec listeners;     ss -lntp | awk '{print $4, $6}' | sort -u
sec updates;       apt list --upgradable 2>/dev/null | grep -c upgradable
