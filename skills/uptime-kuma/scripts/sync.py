"""Idempotently sync spec.py GROUPS into Uptime Kuma (create or update by name). Usage: venv/bin/python sync.py [--dry]"""
import sys, json, time
from kuma import Kuma
import spec

DEFAULTS = dict(type="http", parent=None, url="https://", method="GET", interval=60, retryInterval=60, resendInterval=0, maxretries=0,
    notificationIDList={}, ignoreTls=False, upsideDown=False, expiryNotification=False, domainExpiryNotification=False, maxredirects=10,
    accepted_statuscodes=["200-299"], dns_resolve_type="A", dns_resolve_server="1.1.1.1", docker_container="", docker_host=None, proxyId=None,
    basic_auth_user="", basic_auth_pass="", authMethod=None, httpBodyEncoding="json", kafkaProducerBrokers=[], kafkaProducerSaslOptions={"mechanism": "None"},
    kafkaProducerSsl=False, kafkaProducerAllowAutoTopicCreation=False, gamedigGivenPortOnly=True, conditions=[], rabbitmqNodes=[],
    rabbitmqUsername="", rabbitmqPassword="", timeout=30, description="", keyword="", invertKeyword=False, jsonPath="", expectedValue="", jsonPathOperator="==",
    packetSize=56, ping_count=1, ping_numeric=True, ping_per_request_timeout=2, cacheBust=False, saveResponse=False, saveErrorResponse=True, responseMaxLength=1024,
    ipFamily=None, retryOnlyOnStatusCodeFailure=False, wsSubprotocol="", location="world", protocol=None)

def main(dry=False):
    k = Kuma(); k.login()
    mons = k.wait("monitorList") or {}
    by_name = {m["name"]: m for m in mons.values()}
    notif_ids = {str(n["id"]): True for n in (k.wait("notificationList") or []) if n.get("isDefault")}
    def upsert(m):
        cur = by_name.get(m["name"])
        if cur:
            full = k.emit("getMonitor", cur["id"])["monitor"]
            full.update(m); full["notificationIDList"] = {**{str(x): True for x in (full.get("notificationIDList") or {})}, **notif_ids}
            # Kuma JSON-encodes conditions server-side; send a list (a string gets double-encoded -> "conditions.forEach is not a function")
            while isinstance(full.get("conditions"), str): full["conditions"] = json.loads(full["conditions"] or "[]")
            r = k.emit("editMonitor", full) if not dry else {"ok": True}
            return cur["id"], "upd", r
        body = {**DEFAULTS, **m, "notificationIDList": dict(notif_ids)}
        if body["type"] == "ping": body["timeout"] = min(body.get("timeout", 10), 10)
        r = k.emit("add", body) if not dry else {"ok": True, "monitorID": -1}
        return r.get("monitorID"), "add", r
    for g, children in spec.GROUPS.items():
        gid, act, r = upsert(dict(type="group", name=g, description=f"Group: {g}", interval=60))
        print(f"[{act}] group {g} -> {gid} {r.get('ok')} {r.get('msg','')}")
        for c in children:
            mid, act, r = upsert({**c, "parent": gid})
            if not r.get("ok"): print(f"   !! {act} {c['name']}: {r.get('msg')}")
            else: print(f"   [{act}] {c['name']} -> {mid}")
            time.sleep(0.2)
    k.close()

if __name__ == "__main__":
    main("--dry" in sys.argv)
