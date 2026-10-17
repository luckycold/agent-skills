# SteamRT3 launcher diagnosis

A connected 6 GHz adapter does not prove SteamVR can start. A verified host
failure had these combined symptoms:

- Steam reported `k_ERemoteClientWaitVRConnectionReady` timeout.
- `vrserver.txt` repeatedly reported that `vrcompositor` was not running, then
  aborted on a connection watchdog timeout.
- `vrstartup-linux.txt` reported `Unable to connect to any of the specified bus
  names (is steam-runtime-launcher-service running?)`.
- `busctl --user list` showed only a per-instance
  `com.steampowered.PressureVessel.LaunchAlongsideSteam.Instance…` name; the plain
  `com.steampowered.PressureVessel.LaunchAlongsideSteam` name was absent.

This matches [Valve's SteamVR issue 936](https://github.com/ValveSoftware/SteamVR-for-Linux/issues/936).
Confirm installed behavior rather than assuming an upstream fix or a removed
UI toggle applies to the host.

## Native client opt-out

Inspect the installed `steam.sh` first. The observed version explicitly
supports `STEAM_FORCE_CLIENT=scout` (also `ubuntu12_32` or `ldlp`) and persists
that choice by creating `$STEAMROOT/.steam-disable-steamrt64-client`.
`STEAM_FORCE_CLIENT=steamrt64` removes the sentinel and restores the default.
The opt-out remains available in that launcher even without its former UI.

If this path is present, prefer it to a custom launcher service or patched
Valve scripts. Discover the Steam root and existing launch service/flags.
Create the native sentinel in that root, request a graceful `steam -shutdown`,
and restart through the existing launcher after the client exits. This is a
runtime selection; it does not require switching the client release channel.
Record whether the sentinel already existed for rollback.

On the verified host, restart selected `ubuntu12_32/steam`, restored the scout
runtime, and registered both the plain and per-instance launcher bus names.
Treat this as verification of launcher recovery only until streaming succeeds.
To undo a newly created opt-out, remove the sentinel and restart Steam normally.

## Verify the complete path

1. Confirm the client executable and plain launcher name through `pgrep` and
   `busctl --user list`.
2. Rediscover the adapter and verify its association after the restart.
3. Keep the headset awake and initiate a fresh streaming connection. Starting
   SteamVR alone can leave it waiting for a headset session.
4. Confirm a live `vrcompositor`, fresh compositor logs, and headset-side video.
   Do not report an end-to-end fix from a bus name or Wi-Fi association alone.

Low-latency helper `No such device (-19)` errors also occurred with
`wpa_supplicant`. That message alone does not establish an iwd failure or justify
patching the helper; require the backend authentication evidence in the parent
skill before changing backends.
