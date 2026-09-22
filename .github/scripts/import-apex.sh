#!/usr/bin/env bash
# Imports the clean APEXlang app copy into the remote target, overriding the
# target application id (see .claude/skills/deploy/SKILL.md section 5B).
set -euo pipefail

CONN="$WMS_DB_CONNECT_STRING"
CLEAN="$RUNNER_TEMP/26house-clean-app"

sql -S /nolog <<SQL
whenever sqlerror exit sql.sqlcode
connect $CONN
apex import -input "$CLEAN" -id $WMS_APP_ID -workspaceid $WMS_WORKSPACE_ID
exit
SQL
