"""Suppress Kuma alerts during bulk changes. Usage: venv/bin/python maintenance.py start|stop
start: create a manual maintenance window covering every monitor. stop: delete Labby's maintenance windows."""
import sys
from kuma import Kuma
TITLE = "Labby setup/tuning (suppress alerts)"
k = Kuma(); k.login()
if sys.argv[1:] == ["start"]:
    mons = k.wait("monitorList") or {}
    m = {"title": TITLE, "description": "Remove when done.", "strategy": "manual", "active": True, "intervalDay": 1,
         "dateRange": [None, None], "timeRange": [{"hours": 0, "minutes": 0}, {"hours": 0, "minutes": 0}], "weekdays": [],
         "daysOfMonth": [], "timezoneOption": "SAME_AS_SERVER", "cron": "30 3 * * *", "durationMinutes": 60}
    mid = k.emit("addMaintenance", m)["maintenanceID"]
    print(k.emit("addMonitorMaintenance", mid, [{"id": int(i)} for i in mons]).get("ok"), "maintenance", mid, len(mons))
elif sys.argv[1:] == ["stop"]:
    for mt in (k.wait("maintenanceList") or {}).values():
        if mt.get("title") == TITLE:
            print("deleted", mt["id"], k.emit("deleteMaintenance", mt["id"]).get("ok"))
else:
    print(__doc__)
k.close()
