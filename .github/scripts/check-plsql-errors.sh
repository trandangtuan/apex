#!/usr/bin/env bash
# Fails the job if any object left behind a compile error after the DDL/PL-SQL
# deploy steps.
set -euo pipefail

CONN="$WMS_DB_CONNECT_STRING"

sql -S "$CONN" <<'SQL' > /tmp/user_errors.txt
set heading off
set feedback off
set pagesize 0
set linesize 200
select name || ' ' || type || ' line ' || line || ': ' || text from user_errors order by name, type, sequence;
exit
SQL

cat /tmp/user_errors.txt
if [ -s /tmp/user_errors.txt ] && grep -q '[A-Za-z]' /tmp/user_errors.txt; then
  echo "::error::PL/SQL compile errors found in user_errors, see log above"
  exit 1
fi
