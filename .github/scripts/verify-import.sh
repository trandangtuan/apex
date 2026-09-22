#!/usr/bin/env bash
# Sanity check: confirms app 100 still has pages after the import.
set -euo pipefail

CONN="$WMS_DB_CONNECT_STRING"

sql -S "$CONN" <<SQL
select count(*) page_count from apex_application_pages where application_id = $WMS_APP_ID;
exit
SQL
