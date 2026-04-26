#!/usr/bin/env bash
set -euo pipefail

sqlite="output/sqlite/nga_west3_20250919.sqlite"
test -f "$sqlite"

required_tables="$(sqlite3 "$sqlite" "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name IN ('events','stations','sites','motions','intensity_measures');")"
test "$required_tables" -eq 5

sqlite3 "$sqlite" <<'SQL'
SELECT event_id, event_name, magnitude, event_type
FROM events
WHERE hypocenter_longitude IS NOT NULL
  AND hypocenter_latitude IS NOT NULL
LIMIT 5;
SQL

test "$(sqlite3 "$sqlite" 'SELECT count(*) FROM events;')" -gt 0
test "$(sqlite3 "$sqlite" 'SELECT count(*) FROM stations;')" -gt 0
test "$(sqlite3 "$sqlite" 'SELECT count(*) FROM motions;')" -gt 0
