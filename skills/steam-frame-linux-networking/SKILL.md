---
name: steam-frame-linux-networking
description: Diagnose Steam Frame wireless adapter pairing, endless Waiting status, and dedicated-link authentication failures on Linux or SteamOS, including radio blocks and the supported SteamOS Wi-Fi backend setting.
author: Luke
---

# Steam Frame adapter on Linux

Use host evidence to distinguish pairing from establishing the dedicated link.
Repeated unpairing or rebooting does not address a disabled radio or a failing
Wi-Fi backend. Confirm which host has the adapter and keep the headset awake
during connection tests.

## Inspect before changing

Discover the Steam installation, adapter interface, and current versions:

```bash
uname -r
lsusb
nmcli radio
rfkill list wifi
nmcli -f DEVICE,TYPE,STATE device
iw reg get
```

Check Steam's `logs/remote_connections.txt` and `logs/client_networkmanager.txt`,
plus recent NetworkManager and Wi-Fi backend journal messages. Avoid displaying
secrets or preserving live SSIDs, addresses, identifiers, or raw logs in skills.

Download and inspect the current
[Valve diagnostic](https://github.com/ValveSoftware/SteamVR-for-Linux/blob/master/frame-dongle-troubleshoot.sh)
before running it. It can run without root; some firewall checks may be skipped.
Treat its success as a prerequisite check, not proof of an established link.

- A global Wi-Fi soft block also disables the USB adapter. `nmcli radio wifi on`
  cleared this verified blocker; confirm with `rfkill` afterward.
- An unset regulatory domain can resolve automatically after enabling Wi-Fi.
  Recheck before proposing a country change. Use the actual physical country;
  ask if unknown rather than inferring it from timezone or choosing US blindly.
- Verify the required ports against active firewall rules. An active firewall
  alone does not establish that it is blocking Steam Frame traffic.
- Apply a downloaded Steam update through a graceful Steam restart when
  appropriate; discover the existing launcher/service and preserve its flags.
  Do not create a restart wrapper or change release channels without need.

## SteamOS backend failure

A verified failure pattern with `iwd` combined:

- `IWD agent request for a wrong network object` / `supplicant-failed` during
  activation of `Steam Frame Wireless Adapter`.
- Steam's Realtek helper selected a `wlan*-p2p` interface and emitted
  `No such device (-19)` while setting low-latency mode.

The helper's `list` command can expose its selected interface:

```bash
/usr/bin/holo-polkit-helpers/holo-realtek-firmware-toggles list
```

Inspect the installed SteamOS manager interface before using this supported
setting; availability may vary. Its XML is normally under
`/usr/share/dbus-1/interfaces/com.steampowered.SteamOSManager1.xml`.

```bash
busctl --user get-property com.steampowered.SteamOSManager1 \
  /com/steampowered/SteamOSManager1 \
  com.steampowered.SteamOSManager1.WifiBackend1 WifiBackend
busctl --user set-property com.steampowered.SteamOSManager1 \
  /com/steampowered/SteamOSManager1 \
  com.steampowered.SteamOSManager1.WifiBackend1 WifiBackend s wpa_supplicant
```

For the observed failure, switching to `wpa_supplicant` through this native
property established the dedicated 6 GHz connection. Record the original
backend, account for network interruption, and revert through the same property
if the test fails. Do not treat this as a universal backend preference or patch
Valve's helper speculatively.

Backend transitions can recreate or rename interfaces. Rediscover them with
`nmcli` and `iw dev`; do not reuse a hard-coded `wlan` name. Verify that the
Valve adapter's interface is connected to the headset and reports the dedicated
frequency. Then ask for headset-side status and an actual streaming test; host
association alone does not prove streaming works.

## Self-maintenance

Follow `personal-skill-maintenance` for verified reusable corrections. Keep
environment values and transient diagnosis out of the public package.
