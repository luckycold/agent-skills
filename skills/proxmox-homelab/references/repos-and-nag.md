# No-subscription repos and subscription-nag removal (PVE 9 / trixie)

Hand-applied equivalent of the community-scripts `tools/pve/post-pve-install.sh`
(ProxmoxVE helper scripts). Re-read the upstream script before reusing this; it
changes. Do it on **every** cluster node. Skip the script's HA/corosync disabling
(nodes may rely on `watchdog-mux` + a hardware watchdog via pve-ha-manager), its
`dist-upgrade` and its reboot: those need the owner's OK.

## 1. Survey (read-only)
```sh
pveversion; grep VERSION_CODENAME /etc/os-release
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do echo "--- $f"; cat "$f"; done
cat /etc/apt/apt.conf.d/*nag* 2>/dev/null
dpkg -l ceph-common | tail -1       # match the Ceph release already installed
```
A daily `401 Unauthorized` from `enterprise.proxmox.com` means an enabled
`pve-enterprise` (or Ceph enterprise) source without a subscription.

## 2. Backups
Keep backups **outside** `/etc/apt/sources.list.d` and `/etc/apt/apt.conf.d`
(apt warns about odd extensions in the first and *parses* every file in the
second). Use e.g. `/root/<agent>-backups-YYYYMMDD/<name>.bak-YYYYMMDD-<agent>`
for each changed `.sources`, the old `no-nag-script`, `proxmoxlib.js` and
`/usr/share/pve-yew-mobile-gui/index.html.tpl`.

## 3. Repos (deb822, the script's "disable" choice)
- Any `*.sources` with `Components: pve-enterprise` or an
  `enterprise.proxmox.com.*ceph` URI: set `Enabled: false` (replace an existing
  `Enabled:` line or append one). Legacy `.list` lines get commented with `# `.
- If no `Components: pve-no-subscription` exists, write
  `/etc/apt/sources.list.d/proxmox.sources`:
  `Types: deb` / `URIs: http://download.proxmox.com/debian/pve` / `Suites: trixie` /
  `Components: pve-no-subscription` / `Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg`
- If no `Components: no-subscription` (Ceph) exists, write `ceph.sources` the same
  way with `URIs: http://download.proxmox.com/debian/ceph-<release>`. Upstream picks
  `ceph-tentacle` on PVE >= 9.2 and `ceph-squid` before that. In a cluster, use the
  release the other nodes already run (check `ceph-common` versions) so nodes don't
  diverge.
- pve-test (optional) is added with `Enabled: false`.

## 4. Nag removal
- `/usr/local/bin/pve-remove-nag.sh` (copy verbatim from upstream): if
  `proxmoxlib.js` lacks `NoMoreNagging`, run
  `sed -i -e "/data\.status/ s/!//" -e "/data\.status/ s/active/NoMoreNagging/"`;
  and append a marked `<script>` block to the mobile UI template that removes
  subscription dialogs/cards.
- `/etc/apt/apt.conf.d/no-nag-script`:
  `DPkg::Post-Invoke { "/usr/local/bin/pve-remove-nag.sh"; };` (mode 644). This
  re-patches after every widget-toolkit upgrade. It replaces the older inline
  `dpkg -V ...` hook some hosts carry.
- Run the script once (upstream triggers it via
  `apt --reinstall install proxmox-widget-toolkit`; calling it directly is
  equivalent and lighter), then `systemctl restart pveproxy` only.
- Verify: `grep -c NoMoreNagging proxmoxlib.js` >= 1, `curl -sk -o /dev/null
  -w '%{http_code}' https://127.0.0.1:8006/` is 200. Tell the user to hard-reload.

## 5. Verify
`apt-get update 2>&1 | grep -E '^(W|E):|401'` prints nothing on each node;
`apt list --upgradable | wc -l`; `apt-get -s dist-upgrade` for NEW packages
(a new `proxmox-kernel-*-signed` means a reboot to use it); `pvecm status`
still quorate; `ha-manager status` unchanged.
