#!/bin/bash
# Usage: bash fio-chunk-test.sh <zpool> <mountpoint-with-ample-free-space>
# PBS-chunk-store-like test: writes 2 GiB (512 x 4 MiB files, 1 MiB direct I/O, end_fsync)
# into a hidden temp dir, reads it back, then deletes it. Prints fio avg/min/max
# (per 0.5 s sample) and per-second pool/vdev write MB/s from `zpool iostat`.
# Run only on pools with plenty of free space, in a quiet window, with Luke's OK.
set -u
pool=${1:?zpool name}; dir=${2:?mountpoint}
d="$dir/.agent-fio-$$"; tmp=$(mktemp -d)
cleanup(){ rm -rf "$d"; [ -e "$d" ] && echo "CLEANUP FAILED: $d" || echo "cleanup ok"; rm -rf "$tmp"; }
trap cleanup EXIT
echo "== $pool @ $(date +%T) io-psi: $(head -1 /proc/pressure/io 2>/dev/null)"
mkdir "$d" || exit 1
zpool iostat -vy "$pool" 1 180 > "$tmp/iostat.txt" 2>&1 & IP=$!
common=(--directory="$d" --nrfiles=512 --filesize=4M --bs=1M --ioengine=psync --direct=1 --output-format=json)
fio --name=chunks --rw=write --end_fsync=1 --create_on_open=1 "${common[@]}" > "$tmp/w.json" 2>"$tmp/w.err"
fio --name=chunks --rw=read "${common[@]}" > "$tmp/r.json" 2>"$tmp/r.err"
kill $IP 2>/dev/null; wait $IP 2>/dev/null
python3 - "$tmp" <<'PY'
import json,sys
t=sys.argv[1]
for k in ("write","read"):
    f=f"{t}/{k[0]}.json"
    try:
        j=json.load(open(f))["jobs"][0][k]
        print(f"{k}: avg {j['bw']/1024:.0f} MiB/s  min {j['bw_min']/1024:.0f}  max {j['bw_max']/1024:.0f}  "
              f"stdev {j['bw_dev']/1024:.0f}  runtime {j['runtime']/1000:.1f}s  io {j['io_bytes']/2**30:.2f}GiB")
    except Exception as e:
        print(k, "ERR", e, open(f"{t}/{k[0]}.err").read()[:300])
PY
echo "-- per-second write bandwidth per pool/vdev/disk (names truncated to 12 chars):"
awk 'NF==7 && $1!="pool" && $1 !~ /^-/ {a[$1]=a[$1]" "$7} END{for(k in a) print substr(k,1,12)":"a[k]}' "$tmp/iostat.txt"
