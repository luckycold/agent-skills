"""Print non-UP monitors (status 0=down,1=up,2=pending,3=maintenance). Usage: venv/bin/python status.py [--all]"""
import sys, time
from kuma import Kuma
k = Kuma(); k.login(); time.sleep(4)
mons = k.wait("monitorList") or {}
names = {str(m["id"]): m for m in mons.values()}
S = {0: "DOWN", 1: "UP", 2: "PENDING", 3: "MAINT", None: "NODATA"}
cnt = {}
for mid, m in sorted(names.items(), key=lambda x: int(x[0])):
    if m["type"] == "group": continue
    h = k.hb.get(mid) or {}
    st = h.get("status") if m.get("active") else "PAUSED"
    lab = S.get(st, st); cnt[lab] = cnt.get(lab, 0) + 1
    if lab != "UP" or "--all" in sys.argv:
        print(f"{mid:>4} {lab:8} {m['name'][:45]:45} {(h.get('msg') or '')[:110]}")
print(cnt); k.close()
