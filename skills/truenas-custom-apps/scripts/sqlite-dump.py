#!/usr/bin/env python3
"""Nightly consistent copies of app SQLite DBs (+ small config files) on TrueNAS, for off-site Backrest plans.
Runs from TrueNAS cron as root: 02:45 all jobs, 05:40 `hass` (newest HA automatic backup). Each DB is opened READ-ONLY (file:...?mode=ro, never creates -wal/-shm, no app restart)
and copied with the SQLite online-backup API, then PRAGMA integrity_check'ed, zstd'ed, sha1'ed into
$OUT/<app>/ (apps:apps 0600, latest-* symlinks). Small config files go into files_<app>_<ts>.tar.zst.
zstd --rsyncable keeps restic dedup working across days. Cleanup is MANIFEST-BASED (<dir>/.labby-dump.manifest): only files this script wrote are deleted, after keep_days.
Usage: labby-sqlitedump.py [app ...]   See proxmox-homelab/references/backup-health.md section 6."""
import os, re, sys, sqlite3, subprocess, hashlib, time, glob, shutil, syslog, urllib.parse, pwd, grp
OUT = "/mnt/<apps-pool>/Applications/db-dumps"; A = "/mnt/<apps-pool>/Applications"; M = "/mnt/.ix-apps/app_mounts"
PLEX = f"{A}/plex/config/Library/Application Support/Plex Media Server"
EXCL = ["*.db", "*.db-*", "*.sqlite", "*.sqlite-*", "*.sqlite3", "*.sqlite3-*", "*.pid", "*.lock", "logs", "log", "cache", "Cache", "lost+found"]
# app: dbs (absolute paths), tar (base, [relative members]), keep_days, newest_glob (copy newest matching file as-is)
JOBS = {   # examples; list the live DB files (from `docker inspect` mounts), never stale copies in old app_mounts dirs
 "<app>": dict(dbs=[f"{A}/<app>/config/<app>.db"], tar=(f"{A}/<app>/config", ["config.xml"])),
 "plex": dict(dbs=[f"{PLEX}/Plug-in Support/Databases/com.plexapp.plugins.library.db",
                   f"{PLEX}/Plug-in Support/Databases/com.plexapp.plugins.library.blobs.db"], tar=(PLEX, ["Preferences.xml"])),
 "app-configs": dict(tar=("/mnt/.ix-apps", ["app_configs"]), keep_days=14),
 "uptime-kuma": dict(remote=("root@<kuma-ct>", "kuma.db")),  # dump-only key + forced command on the far side, see backup-health
 "hass": dict(newest="/mnt/<apps-pool>/backups/hass/automatic_backup_*.tar", keep_days=3, separate=True),
}
UID, GID = pwd.getpwnam("apps").pw_uid, grp.getgrnam("apps").gr_gid
TS = time.strftime("%Y%m%d-%H%M%S"); rc = 0
def log(m):
    syslog.syslog(syslog.LOG_INFO, "sqlite-dump: " + m); print(time.strftime("%F %T"), m, flush=True)
def sha1(p):
    h = hashlib.sha1()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""): h.update(b)
    return h.hexdigest()
def finish(d, base, link):
    p = f"{d}/{base}"
    with open(p + ".sha1", "w") as f: f.write(f"{sha1(p)}  {base}\n")
    for x in (p, p + ".sha1"): os.chown(x, UID, GID); os.chmod(x, 0o600)
    with open(f"{d}/.labby-dump.manifest", "a") as f: f.write(base + "\n")
    os.chown(f"{d}/.labby-dump.manifest", UID, GID); os.chmod(f"{d}/.labby-dump.manifest", 0o600)
    l = f"{d}/{link}"; tmp = l + ".new"
    if os.path.lexists(tmp): os.unlink(tmp)
    os.symlink(base, tmp); os.lchown(tmp, UID, GID); os.replace(tmp, l)
def cleanup(d, keep_days):
    m = f"{d}/.labby-dump.manifest"
    if not os.path.exists(m): return
    keep, cut = [], time.time() - keep_days * 86400
    for b in open(m).read().split():
        if "/" in b or b.startswith("."): keep.append(b); continue
        p = f"{d}/{b}"
        if os.path.isfile(p) and os.path.getmtime(p) < cut:
            for x in (p, p + ".sha1"):
                if os.path.exists(x): os.unlink(x)
            log(f"{os.path.basename(d)}: expired {b}")
        elif os.path.exists(p): keep.append(b)
    with open(m + ".tmp", "w") as f: f.write("".join(k + "\n" for k in sorted(set(keep))))
    os.replace(m + ".tmp", m); os.chown(m, UID, GID); os.chmod(m, 0o600)
def zst(src, dst):
    subprocess.run(["zstd", "-q", "-10", "-T0", "--rsyncable", "-f", "-o", dst, src], check=True)
    subprocess.run(["zstd", "-q", "-t", dst], check=True)
def check(dst):
    try:
        return dst.execute("PRAGMA integrity_check").fetchall(), "integrity_check"
    except sqlite3.DatabaseError as e:
        msg = str(e)
        if "collation" in msg:                # Plex: custom icu_root collation -> stub it; quick_check skips index-order checks
            for c in set(re.findall(r"collation sequence: (\w+)", msg)) | {"icu_root"}:
                dst.create_collation(c, lambda a, b: (a > b) - (a < b))
            return dst.execute("PRAGMA quick_check").fetchall(), "quick_check (stub collation)"
        if "malformed database schema" in msg:  # trigger syntax this SQLite build can't parse (Audiobookshelf UPDATE..ORDER BY)
            dst.execute("PRAGMA writable_schema=ON")   # in-memory flag only; lets the check skip the unparsable trigger
            return dst.execute("PRAGMA quick_check").fetchall(), "quick_check (writable_schema)"
        raise
def dump_db(app, d, db):
    if not os.path.isfile(db): raise FileNotFoundError(db)
    stem = os.path.basename(db).replace(" ", "_")
    tmp = f"{d}/.{stem}.{TS}.partial"
    try:
        src = sqlite3.connect("file:" + urllib.parse.quote(db) + "?mode=ro", uri=True, timeout=60)
        dst = sqlite3.connect(tmp)
        try:
            src.backup(dst)                  # one step: consistent snapshot under a read lock; source opened read-only
        finally:
            src.close()
        try:
            try:
                dst.execute("PRAGMA journal_mode=DELETE")   # copy inherits WAL mode; make it one self-contained file
            except sqlite3.DatabaseError as e:
                if "malformed database schema" not in str(e): raise
                dst.execute("PRAGMA writable_schema=ON"); dst.execute("PRAGMA journal_mode=DELETE")
            r, chk = check(dst)
            tables = dst.execute("select count(*) from sqlite_master where type='table'").fetchone()[0]
        finally:
            dst.close()
        if r != [("ok",)]: raise RuntimeError(f"{chk} failed: {r[:3]}")
        base = f"sqlite_{stem}_{TS}.zst"; zst(tmp, f"{d}/.{base}.partial"); raw = os.path.getsize(tmp)
        os.replace(f"{d}/.{base}.partial", f"{d}/{base}"); finish(d, base, f"latest-sqlite_{stem}")
        log(f"{app}: ok {base} raw {raw} B -> {os.path.getsize(f'{d}/{base}')} B, {tables} tables, {chk} ok")
    finally:
        for x in glob.glob(glob.escape(tmp) + "*"): os.unlink(x)
def dump_tar(app, d, base_dir, members):
    base = f"files_{app}_{TS}.tar.zst"; tmp = f"{d}/.{base}.partial"
    ex = sum((["--exclude", e] for e in EXCL), [])
    p1 = subprocess.Popen(["tar", "-C", base_dir, *ex, "-cf", "-", *members], stdout=subprocess.PIPE)
    p2 = subprocess.run(["zstd", "-q", "-10", "-T0", "--rsyncable", "-f", "-o", tmp], stdin=p1.stdout); p1.stdout.close()
    if p1.wait() not in (0, 1) or p2.returncode: raise RuntimeError("tar/zstd failed")
    subprocess.run(["zstd", "-q", "-t", tmp], check=True); os.replace(tmp, f"{d}/{base}"); finish(d, base, f"latest-files_{app}")
    log(f"{app}: ok {base} {os.path.getsize(f'{d}/{base}')} B")
KEY = "/mnt/<apps-pool>/Applications/sqlite-dump/kuma_dump_ed25519"; KH = "/mnt/<apps-pool>/Applications/sqlite-dump/known_hosts"
def dump_remote(app, d, host, name):
    # the key is restricted on the far side to a forced command that prints a consistent .backup copy; we then run the normal pipeline on it
    t = f"{d}/.remote.{TS}.partial"; os.makedirs(t, mode=0o700)
    try:
        with open(f"{t}/{name}", "wb") as f:
            subprocess.run(["ssh", "-T", "-i", KEY, "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", "-o", f"UserKnownHostsFile={KH}",
                            "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=15", host], stdout=f, check=True, timeout=600,
                           env={k: v for k, v in os.environ.items() if k != "SSH_AUTH_SOCK"})
        dump_db(app, d, f"{t}/{name}")
    finally:
        shutil.rmtree(t, ignore_errors=True)
def copy_newest(app, d, pattern):
    fs = sorted(glob.glob(pattern), key=os.path.getmtime)
    if not fs: raise FileNotFoundError(pattern)
    src = fs[-1]; base = os.path.basename(src)
    if os.path.exists(f"{d}/{base}"): log(f"{app}: {base} already copied"); return
    tmp = f"{d}/.{base}.partial"
    subprocess.run(["cp", "--reflink=auto", "--preserve=timestamps", src, tmp], check=True)
    os.replace(tmp, f"{d}/{base}"); finish(d, base, "latest-hass_backup")
    log(f"{app}: ok copied {base} {os.path.getsize(f'{d}/{base}')} B")
sel = sys.argv[1:] or [a for a in JOBS if not JOBS[a].get("separate")]
for app in sel:
    j = JOBS[app]; d = f"{OUT}/{app}"
    os.makedirs(d, exist_ok=True); os.chown(d, UID, GID); os.chmod(d, 0o700)
    for db in j.get("dbs", []):
        try: dump_db(app, d, db)
        except Exception as e: rc = 1; log(f"{app}: FAILED {os.path.basename(db)}: {e}")
    if "tar" in j:
        try: dump_tar(app, d, *j["tar"])
        except Exception as e: rc = 1; log(f"{app}: FAILED tar: {e}")
    if "remote" in j:
        try: dump_remote(app, d, *j["remote"])
        except Exception as e: rc = 1; log(f"{app}: FAILED remote: {e}")
    if "newest" in j:
        try: copy_newest(app, d, j["newest"])
        except Exception as e: rc = 1; log(f"{app}: FAILED copy: {e}")
    for p in glob.glob(f"{d}/.*.partial*"): os.unlink(p)
    cleanup(d, j.get("keep_days", 30))
sys.exit(rc)
