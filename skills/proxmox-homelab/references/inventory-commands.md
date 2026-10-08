# Read-only Proxmox inventory checklist

Run on the primary node as root over the Pass SSH agent. Every command here is read-only. Redact secrets before saving output. In particular, `storage.cfg` can contain storage-plugin API keys (`sed -E 's/(api_key|password|token)[^ ]* .*/\1 [REDACTED]/'`).

## Host and cluster
```bash
pveversion -v | head -40; uname -r; hostnamectl
lscpu | grep -E 'Model name|^CPU\(s\)'; free -h
pvecm status; pvecm nodes
grep -E 'name|ring0_addr' /etc/pve/corosync.conf
apt list --upgradable 2>/dev/null | grep -c upgradable
grep -rh '^[^#]' /etc/apt/sources.list /etc/apt/sources.list.d/   # repo sanity
systemctl --failed --no-legend
ss -lntp | awk '{print $4, $6}' | sort -u                          # extra services
pveum user list --output-format json                               # users/realms/tokens (ids only)
pvenode cert info --output-format json                             # cert SAN/expiry
```

## Guests
```bash
qm list; pct list
pvesh get /cluster/resources --output-format json                  # all nodes, incl. offline ones
for f in /etc/pve/nodes/*/qemu-server/*.conf /etc/pve/nodes/*/lxc/*.conf; do
  echo "--- $f"; sed -n '/^\[/q;p' "$f" | grep -vE '^(cipassword|sshkeys|smbios1|vmgenid)'; done
qm guest cmd <vmid> network-get-interfaces | grep '"ip-address"'   # needs guest agent
pct exec <ctid> -- ip -br -4 a </dev/null
```

## Storage
```bash
pvesm status
zpool list; zpool status -x; zpool status | grep -E 'pool:|state:|scan:|errors:'
lvs; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
wipefs -n /dev/<disk>        # empty output means no signatures (possibly unused disk)
```

## Network
```bash
cat /etc/network/interfaces; ls /etc/network/interfaces.d/
ip -br a; ip r; cat /proc/net/vlan/config
ls /etc/pve/sdn 2>/dev/null; cat /etc/pve/firewall/cluster.fw 2>/dev/null
```

## Backups, replication, HA, notifications
```bash
cat /etc/pve/jobs.cfg; pvesh get /cluster/backup --output-format json-pretty
pvesh get /cluster/backup-info/not-backed-up --output-format json
cat /etc/pve/replication.cfg; pvesr status
ha-manager status; cat /etc/pve/ha/resources.cfg
grep -viE 'secret|token|password|key' /etc/pve/notifications.cfg
journalctl --since -7d -u pvescheduler --no-pager | grep -iE 'vzdump|backup|error'
journalctl --since -2d --no-pager | grep postfix | grep -E 'status=' | tail
```

## Other nodes and PBS
```bash
ssh -n -o BatchMode=yes root@<other-node-ip> 'pveversion; qm list; pct list; zpool status -x'
pct exec <pbs-ctid> -- proxmox-backup-manager datastore list </dev/null
pct exec <pbs-ctid> -- proxmox-backup-manager prune-job list </dev/null
pct exec <pbs-ctid> -- proxmox-backup-manager sync-job list </dev/null
pct exec <pbs-ctid> -- proxmox-backup-manager verify-job list </dev/null
pct exec <pbs-ctid> -- proxmox-backup-manager task list --all --limit 30 </dev/null
```
