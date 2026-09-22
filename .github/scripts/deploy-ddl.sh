#!/usr/bin/env bash
# Applies db/ddl/ files that were added/changed by this merge, in sorted order.
# Not idempotent (plain CREATE TABLE) -- deliberately does NOT rerun unchanged
# older files. Reads the changed-file list produced by the "Detect changed
# paths" workflow step.
set -euo pipefail

CONN="$WMS_DB_CONNECT_STRING"

for f in $(grep '^db/ddl/' /tmp/changed_files.txt | sort); do
  if [ ! -f "$f" ]; then
    echo "=== skip $f (removed by this merge) ==="
    continue
  fi
  echo "=== applying $f ==="
  sql -S "$CONN" <<SQL
whenever sqlerror exit sql.sqlcode rollback
@$f
exit
SQL
done
