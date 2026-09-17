---
name: deploy
description: Build a clean APEXlang app copy, validate it, and import (deploy) the 26HOUSE WMS app into a target Oracle APEX environment (local dev or a named remote). Use when the user asks to "deploy", "import vào APEX", "push app lên", "test và import", or names one of the known targets below.
---

Follow this procedure exactly. Do not skip the clean-copy step or the post-import diff — both have caused real failures on this project before (see `CLAUDE.md`).

## 1. Known targets

| Target name | Connection | `--workspaceid` | Remote `application_id` | Import method |
| --- | --- | --- | --- | --- |
| Local dev (default) | SQLcl connection `admin_freepdb1` | `6802490454262707` (workspace TDT203) | 105 — matches `application.apx`, same id as source | `apexctl.mjs runtime roundtrip` (§5A) |
| Remote / shared | SQLcl connection `wms_remote` = `26HOUSE/26house@18.181.77.39:1521/FREEPDB1` | `2313406132176276` (workspace `26HOUSE`) | **100** — differs from source id 105, resolved only by alias `26HOUSE` | **Direct SQLcl `apex import -id 100`** (§5B) — do **not** use the `apexctl.mjs` wrapper for this target, see why below |

If the user names a target not in this table, or asks to deploy somewhere new, do not guess connection details — ask them for the connection string, or check `sql /nolog` → `connmgr list` for an already-saved name that matches.

If the user just says "deploy" / "test and import" with no target named, **default to remote only (§5B, app 100)** — do not also import to local dev unless explicitly asked. The user asked for this 2026-09-17 after local/remote had drifted into two separate apps on the remote server; keeping remote as the single import target avoids that recurring. DB-level changes (DDL, PL/SQL packages) still need applying to both databases when you change schema/package code — this "remote only" preference is specifically about the APEXlang *page* import step, not package/DDL sync.

**Why the remote target needs a different method:** `application.apx` declares app id 105 (matching local dev). The remote server already had this exact app deployed earlier under a *different* id (100, same alias `26HOUSE`). The `apexctl.mjs runtime roundtrip` wrapper always imports using the source-declared id and has no CLI flag to override it — when tried against the remote target with `--target-resolution-mode update-existing`, it resolved the existing app as id 100 via alias, but then imported as a *new* app 105 (auto-suffixing the alias to `26HOUSE105`) because the wrapper can't redirect the import to id 100, and it correctly failed with `canonical_application_import_target_mismatch` rather than silently leaving two conflicting apps. Clean this up if it recurs (see §8). The underlying native `apex import` command supports `-id <id>` to override the target id on import — that's the supported, correct way to deploy the same app under a different id in a different environment, so use it directly for this target.

## 2. Before importing anywhere new (first time only)

For a target not yet confirmed to already have the WMS schema/app:
```sql
select 'APEX_APP' t, count(*) c from apex_applications where alias = '26HOUSE'
union all
select 'TABLES', count(*) from user_tables where table_name in ('INBOUND_RECEIPT','ITEM','LOCATION','SUPPLIER','WAREHOUSE')
union all
select 'PKG_INBOUND', count(*) from user_objects where object_name = 'PKG_INBOUND' and object_type = 'PACKAGE BODY';
```
- If tables/packages are missing, this is a from-scratch environment — follow `README.md` sections 3.1–3.2 (DDL then PL/SQL packages) before touching APEXlang pages at all.
- If `apex_applications` already has a row for alias `26HOUSE`, note its `application_id` — that is the real target id for `update-existing`, even if it differs from the `application.apx` source id (105). Resolution is by alias/workspace, not by matching the numeric id.

## 3. Build the clean copy

Never point `--app-path` at the repo root — `apexlang/templates/base-app-structure/scaffold-example/` inside this repo is a different sample app and the tool sometimes scans it by mistake.

```bash
CLEAN=/tmp/26house-clean-app
rm -rf "$CLEAN" && mkdir -p "$CLEAN"
cp application.apx page-groups.apx "$CLEAN/"
cp -r pages shared-components deployments .apex "$CLEAN/"
```

## 4. Local lint (advisory only)

```bash
node apexlang/tools/apexctl.mjs apexlang validate --app-path .
```
Known false positives already accepted on this project (do not try to "fix" these): `lov {}` and `masterDetail {}` / `default {}` on Interactive Grid columns, and `IR_CONTEXT_BIND_SUBMIT_REQUIRED_001` on an Interactive Report that already declares `source.pageItemsToSubmit`, all report locally but pass live. Treat local-check failures as advisory — the live roundtrip in step 5 is authoritative. Only stop here if the failure is something you don't already recognize from `CLAUDE.md`.

**Trying a component type/property not seen before in this repo?** Don't experiment against the real app. Write a throwaway single-page `.apx` file, copy it into a disposable clean-app-copy (or just add it alongside the real pages in `/tmp/26house-clean-app`), and run a dry-run compile check with no import side effect:
```bash
sql -S /nolog <<'EOF'
connect -name wms_remote
apex validate -input <path-to-clean-copy-or-file> -workspaceid 2313406132176276
EOF
```
This is a real SQLcl subcommand distinct from `apex import` — it compiles against the live engine but never touches the target application. Iterate here until `Validation successful.`, then apply the syntax to the real page and remove the scratch file. **`Validation successful.` only proves the compiler accepts the syntax, not that the component renders/works at runtime** — after deploying, still ask the user to look at the real page before calling it done. Used this trick to try `type: qrCode` on a pageItem: it compiled clean, but turned out not to render any widget at all in the running app (see `CLAUDE.md`) — reverted.

## 5A. Live validate + import — local dev target

```bash
cd apexlang
timeout 480 node tools/apexctl.mjs runtime roundtrip \
  --app-path "$CLEAN" \
  --db-connection-name admin_freepdb1 \
  --import-intent validate-and-import \
  --target-resolution-mode update-existing \
  --skip-runtime-verification \
  --execution-mode path \
  --workspaceid 6802490454262707
```
- `--workspaceid` is mandatory, or the run fails with `lookup_scope_workspace_missing`.
- Run in the background and poll/await — this can take minutes once the app has 20+ pages; `timeout 480` (or more) avoids a mid-run `live_validate_timeout`.
- Read the JSON result at the end. Success looks like `"live_check_status": "pass"`, `"import_status": "pass"`, `"problem_count": 0`. Anything else — read `problems_path` / `transcript_path` from the JSON for the real compiler error text before touching the `.apx` files again.
- If you see `failure_class: create_new_resolved_existing_app`, you used the wrong `--target-resolution-mode` — switch to `update-existing`; the resolver will map by alias to whatever `application_id` already exists there.
- If you ever see `failure_class: canonical_application_import_target_mismatch` on *any* target, that target's remote `application_id` differs from the source id — stop, do not retry the wrapper, and use the §5B direct-import method instead (record the discovered id in §1's table).
- **Once the app reaches ~23+ pages, `apexctl.mjs runtime roundtrip` can fail with `failure_class: live_validate_timeout` even when the underlying SQLcl compile actually succeeded** — the wrapper's internal `live_validate` stage budget is a hardcoded 30s that `--timeout` on the outer shell command cannot change. Before assuming a real error: read `problems_path` (from the JSON result) — if the transcript excerpt inside it literally contains `"Validation successful."`, this is a wrapper misclassification, not a compile error. In that case, skip the wrapper entirely and import directly via §5B's method (with `-workspaceid` but no `-id`, since local dev's app id already matches source):
  ```bash
  sql -S /nolog <<'EOF'
  connect -name admin_freepdb1
  apex import -input /tmp/26house-clean-app -workspaceid 6802490454262707
  EOF
  ```

## 5B. Live validate + import — remote target (id override required)

Validate locally first (still useful — catches real syntax errors even though `apexctl.mjs runtime roundtrip` itself won't be used for the actual import):
```bash
node apexlang/tools/apexctl.mjs apexlang validate --app-path .
```
Then import directly via SQLcl, overriding the target application id explicitly. **`sql -S <saved-connection-name>` does NOT work** for a saved/named connection (it errors with a bare "Connection failed") — you must go through `/nolog` + `connect -name`:
```bash
sql -S /nolog <<'EOF'
connect -name wms_remote
apex import -input /tmp/26house-clean-app -id 100 -workspaceid 2313406132176276
EOF
```
- Expect output `Importing application ID: 100 into workspace: 26HOUSE` then `Import successful.` Anything else (compile errors, `INVALID_PROPERTY`, etc.) means fix the `.apx` source and retry — this command does not run the wrapper's local/live validate stages, so read the SQLcl output carefully yourself.
- Do **not** add `-alias`/`-name` overrides here — the app already has the right alias/name; only `-id` is needed to redirect the import to the pre-existing app.
- Confirm afterward: `select page_id, page_name from apex_application_pages where application_id = 100 order by page_id;` against `wms_remote` and check the expected new/changed pages are present.

## 6. Verify no drift

```bash
diff -rq /tmp/26house-clean-app/pages pages
diff -rq /tmp/26house-clean-app/shared-components shared-components
```
Both should report no differences — import does not write back into the repo, so this just confirms the clean copy truly matched what's committed before it was imported.

## 7. Report back

State plainly: which target(s) were updated, the resulting `application_id` there (may differ from 105, see table above), and the pass/fail status. If a target's `application_id` differs from the source repo's declared id, record that pairing in this file's table so it isn't re-discovered by trial and error next time.

## 8. Cleaning up a stray duplicate app (if step 5A was wrongly used against a mismatched-id target)

There is no supported SQLcl or scriptable command to delete an APEX application in this environment (`apex` has no `delete`/`remove` subcommand, and the internal `wwv_flow_api` package is undocumented/unsafe to call directly against a shared instance). If a duplicate app gets created by mistake:
- Do not attempt to delete it via raw SQL against APEX metadata tables — this can corrupt shared workspace/catalog state affecting other apps.
- Ask whoever has App Builder access on that workspace to delete it via **App Builder → the app → Utilities → Advanced → Delete This Application**.
- Prevent recurrence by always checking §1's table (or running §2's existence check) before importing to a target that hasn't been imported to before.
