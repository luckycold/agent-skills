"""Thin Uptime Kuma v2 socket.io client (Labby). Reads creds from Proton Pass; never prints them."""
import os, subprocess, threading, time, json
import socketio

URL = os.environ.get("KUMA_URL", "http://<kuma-ip>:3001")
ITEM = os.environ.get("KUMA_PASS_ITEM_ID", "")  # Pass item id of the Kuma admin login (see private context)

def pass_field(field, item=None, vault=os.environ.get("KUMA_PASS_VAULT", "Agents")):
    item = item or ITEM
    env = dict(os.environ)
    cmd = f'source ~/.config/proton-pass-cli/env && pass-cli item view --vault-name {vault} --item-id "{item}" --field {field}'
    return subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, env=env, check=True).stdout.strip()

class Kuma:
    def __init__(self, url=URL):
        self.sio = socketio.Client(reconnection=False)
        self.state = {}
        for ev in ["monitorList", "notificationList", "statusPageList", "apiKeyList", "maintenanceList", "proxyList", "dockerHostList", "info"]:
            self.sio.on(ev, self._store(ev))
        self.hb = {}
        self.sio.on("heartbeatList", lambda mid, lst, *a: self.hb.__setitem__(str(mid), lst[-1] if lst else None))
        self.sio.on("heartbeat", lambda d: self.hb.__setitem__(str(d.get("monitorID")), d))
        self.sio.connect(url, transports=["websocket"], wait_timeout=20)
        time.sleep(1)

    def _store(self, ev):
        def h(*a):
            self.state[ev] = a[0] if a else None
        return h

    def call(self, ev, *args, timeout=60):
        return self.sio.call(ev, args if len(args) > 1 else (args[0] if args else None), timeout=timeout) if len(args) <= 1 else self.sio.call(ev, list(args) and tuple(args), timeout=timeout)

    def emit(self, ev, *args, timeout=60):
        ev_done = threading.Event(); out = {}
        def cb(*r):
            out["r"] = r[0] if r else None; ev_done.set()
        self.sio.emit(ev, tuple(args), callback=cb)
        if not ev_done.wait(timeout):
            raise TimeoutError(ev)
        return out["r"]

    def login(self):
        r = self.emit("login", {"username": pass_field("username"), "password": pass_field("password"), "token": ""})
        if not r.get("ok"):
            raise RuntimeError(f"login failed: {r.get('msg')}")
        time.sleep(2)
        return r

    def wait(self, ev, t=15):
        end = time.time() + t
        while ev not in self.state and time.time() < end:
            time.sleep(0.3)
        return self.state.get(ev)

    def close(self):
        self.sio.disconnect()
