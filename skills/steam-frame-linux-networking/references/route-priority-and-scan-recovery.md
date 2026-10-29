# Ethernet priority and adapter scan recovery

## Keep Ethernet first

Leave the global Wi-Fi radio enabled for the USB adapter. Discover the wired,
ordinary Wi-Fi, and adapter connection profiles with `nmcli connection show`.
Record their original values before changing routing preferences.

For an Ethernet-first request, use NetworkManager's persistent route metrics.
Lower metrics win within an address family:

```bash
nmcli connection modify "$wired_profile" ipv4.route-metric 100 ipv6.route-metric 100
nmcli connection modify "$wifi_profile" ipv4.route-metric 600 ipv6.route-metric 600
nmcli connection modify "$adapter_profile" ipv4.never-default yes ipv6.never-default yes
nmcli device reapply "$wired_interface"
nmcli device reapply "$wifi_interface"
```

Only reapply profiles on connected devices. Keep ordinary Wi-Fi autoconnect
enabled for fallback. Check both `ip route show default` and
`ip -6 route show default`, plus the selected interface with `ip route get`
for a public destination. Metrics apply separately to IPv4 and IPv6; a Wi-Fi
IPv6 route can still be used if Ethernet has no usable IPv6 route. Do not claim
failover was tested unless it was actually exercised. Steam may recreate its
adapter profile at startup; verify its routing settings again after a restart.

## Recover a stuck scan after disconnection

A verified SteamOS case had an established 6 GHz association interrupted by
another activation request. Afterward, wpa_supplicant repeatedly logged
`CTRL-EVENT-SCAN-FAILED ret=-16` and NetworkManager failed with `ssid-not-found`.
The native Realtek helper showed `HW_SCAN: X`; earlier low-latency requests had
failed with `No such device (-19)`. This is evidence for a targeted live test,
not proof that every scan failure shares this cause.

1. Read fresh `nmcli` state and `iw dev "$adapter_interface" link`. If already
   associated or connecting, inspect progress before issuing another activation.
   Steam's own retry can replace an overlapping `nmcli connection up` request.
2. Inspect `/usr/bin/holo-polkit-helpers/holo-realtek-firmware-toggles` and its
   `list` output. The observed helper applies changes to every Realtek PHY;
   account for built-in Wi-Fi as well as the USB adapter.
3. With the adapter disconnected and hardware scanning disabled, restore the
   native default using the installed command:

   ```bash
   /usr/bin/holo-polkit-helpers/holo-realtek-firmware-toggles set-feature HW_SCAN on
   nmcli device wifi rescan ifname "$adapter_interface"
   ```

4. Let Steam reconnect, or activate the existing adapter profile once after a
   fresh disconnected-state check. Do not create another profile or expose its
   password. The verified recovery established a 6 GHz association and DHCP
   lease after this change; Steam can reapply its low-latency settings later.
5. Verify association, route selection, live SteamVR/compositor processes, and
   headset-side video. Idle link counters alone do not prove video is streaming.

Do not patch the helper or switch Wi-Fi backends solely because of `-19`.
Preserve the original feature state for rollback if the targeted test fails.

## Connected adapter with an inactive streaming path

Association and VR transport are separate. After a disconnect/reconnect, an
observed session with `driver_vrlink.allowMultipleLinks=false` retained its
home-network path; the connected adapter carried only small control traffic.
SteamVR reported video-reset bursts and measurable packet loss on that path.

Check `driver_vrlink.txt` for the interfaces bound by `SVLDataLinkTransferUDP`.
Compare `iw dev "$adapter_interface" link` counters over time with the runtime's
link activity and quality. In the inspected Steam UI, `streamingStore.vrLinkStatus`
reported type `2` for the dedicated adapter and type `3` for the home-network
path; confirm installed mappings before relying on these numeric values.

The supported live recovery was:

```bash
"$steamvr_dir/bin/linux64/vrcmd" --background \
  --set-settings-bool driver_vrlink.allowMultipleLinks 1
"$steamvr_dir/bin/linux64/vrcmd" --background \
  --settings-bool driver_vrlink.allowMultipleLinks
```

Within seconds the runtime bound the adapter again, adapter transmit counters
increased rapidly, and reported packet loss reached zero. This avoids another
Wi-Fi reconnection or a Steam restart. It allows simultaneous streaming paths;
ordinary internet route metrics continue to prefer Ethernet. Keep the original
setting for rollback and verify sustained traffic and headset video. Disabling
multiple links may be useful for other faults, but does not enforce adapter-only
streaming and can prevent a recovered adapter from rejoining the current session.
