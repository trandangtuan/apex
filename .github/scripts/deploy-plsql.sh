#!/usr/bin/env bash
# Deploys the full db/plsql/ package set in dependency order (see README.md
# section 3.2). CREATE OR REPLACE PACKAGE is idempotent, so this always runs
# the complete list rather than just the files changed by this merge.
set -euo pipefail

CONN="$WMS_DB_CONNECT_STRING"

for f in pkg_item pkg_location pkg_lot pkg_inventory pkg_inbound pkg_outbound pkg_picking pkg_packing pkg_shipment pkg_quality pkg_integration_out pkg_integration_in; do
  echo "=== applying db/plsql/$f.sql ==="
  sql -S "$CONN" <<SQL
whenever sqlerror exit sql.sqlcode rollback
@db/plsql/$f.sql
exit
SQL
done
