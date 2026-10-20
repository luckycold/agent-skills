#!/bin/sh
# Forced command for the NAS's dump-only ssh key (authorized_keys: from="<dump host>",command="this script",restrict).
# Writes a consistent copy of Uptime Kuma's live SQLite DB to stdout. Read-only open + online backup API: no Kuma restart, no locks held long.
set -eu
umask 077
T=$(mktemp -d /tmp/labby-kuma.XXXXXX); trap 'rm -rf "$T"' EXIT
sqlite3 -readonly /opt/uptime-kuma/data/kuma.db ".timeout 60000" ".backup '$T/kuma.db'"
[ "$(sqlite3 "$T/kuma.db" 'PRAGMA quick_check')" = ok ] || { echo "quick_check failed" >&2; exit 2; }
cat "$T/kuma.db"
