# PROJECT-PLAN.md — Hệ thống WMS 26house (Goldmann / SIEA)

> Nguồn: `26house-new-system.docx` + khảo sát mã nguồn dự án (`application.apx`, `page-groups.apx`, `apexlang/`).
> Trạng thái hiện tại của app: skeleton gần như trống (page 0 global rỗng, page 1 home rỗng, page 9999 login chuẩn), dùng bộ công cụ **APEXlang** để sinh file `.apx` (DSL metadata Oracle APEX) qua vòng lặp generate → review → fix → validate (SQLcl) → import. APEXlang **không** sinh bảng DB hay PL/SQL — phần đó phải tự thiết kế và viết tay.

---

## 1. Tóm tắt yêu cầu nghiệp vụ

### 1.1. Hạng mục bắt buộc (OIP commitments — SIEA sẽ đối chiếu với Báo cáo cuối cùng)

| ID | Hạng mục | Ghi chú |
| --- | --- | --- |
| FR-01 | Cơ sở dữ liệu tập trung về hàng tồn kho (10.000+ thiết bị: đầu đọc sinh trắc học, đầu đọc thẻ chip, màn hình, TV display, tablet, mobile, e-poster, loa, đầu đọc chữ ký số, media player), theo dõi vị trí lưu trữ + số lô | Phải có location + lot cho từng thiết bị |
| FR-02 | Tiếp nhận hàng hóa (Inbound) tự động, ghi nhận tồn kho real-time | |
| FR-03 | Soạn hàng có hỗ trợ quét mã vạch/QR (picking) | Yêu cầu rõ trong OIP + Hợp đồng OR |
| FR-04 | Tự động hóa toàn bộ quy trình đơn hàng: tiếp nhận → soạn hàng → đóng gói → xuất hàng, không thao tác thủ công | |
| FR-05 | Tối ưu hóa lưu trữ: phân bổ vị trí + tối ưu tuyến đường lấy hàng | |
| FR-06 | Theo dõi tồn kho real-time theo item/vị trí/lô | Lý do chính triển khai dự án |
| FR-07 | Quản lý chất lượng (Quality Management) | Có tên trong hạng mục công việc của Hợp đồng OR |
| FR-08 | Công cụ báo cáo + dashboard hiệu suất vận hành | |
| FR-09 | Sẵn sàng tích hợp e-shop + hệ thống kế toán (kiến trúc/API, chưa cần hoàn thiện) | |
| FR-10 | KPI đo lường được: độ chính xác kiểm kê/giao hàng ≥ 97%; giảm thời gian xử lý đơn ≥ 25%; giảm chi phí vận hành/số lỗi 25–30% | |

### 1.2. Hoạt động bị cấm (không được tính là chi phí hợp lệ)

| Hoạt động bị cấm | Lý do |
| --- | --- |
| Mua/license phần mềm WMS thương mại có sẵn | Chương trình tài trợ phát triển, không phải mua phần mềm |
| Mua phần cứng (scanner, server, thiết bị) | Loại trừ rõ khỏi chi phí hợp lệ |
| Thiết kế/phát triển website | Hoạt động bị cấm theo Hướng dẫn |
| Module CRM, HR, chấm công, lập hóa đơn | Đổi mới quy trình hỗ trợ bị loại trừ |
| Marketing, quảng bá, hỗ trợ bán hàng | Hoạt động bị cấm |
| Phân tích thị trường/đối thủ cạnh tranh | Hoạt động bị cấm |
| Hỗ trợ IT thường xuyên / bảo trì sau bàn giao | Chi phí không hợp lệ |
| Đào tạo vượt phạm vi onboarding hệ thống | Hoạt động bị cấm |
| Phân tích tài chính/chi phí | Hướng dẫn quy định rõ loại trừ |
| Hoạt động trước 1/6/2026 | Chỉ hoạt động sau khi cấp IP mới hợp lệ |

### 1.3. Vùng ranh giới — cần trình bày đúng cách

| Hạng mục | Cách framing đúng |
| --- | --- |
| Tích hợp e-shop/kế toán | Trình bày là API/integration points thuộc lõi WMS — **không** tách thành dự án tích hợp riêng để tính phí |
| Migration dữ liệu lịch sử | Trình bày là một phần cần thiết của triển khai/kiểm thử — **không** phải dịch vụ dữ liệu độc lập |
| Tài liệu người dùng/hướng dẫn | Chỉ hợp lệ khi là đầu ra của quá trình phát triển: tài liệu kỹ thuật, hướng dẫn vận hành, sơ đồ quy trình |

### 1.4. Đầu ra bắt buộc cho Báo cáo cuối cùng
- Source code + tài liệu (Phụ lục số 3 của ŽoPIP).
- Tài liệu kỹ thuật, hướng dẫn vận hành, sơ đồ quy trình nghiệp vụ.
- Biên bản nghiệm thu (Preberací protokol) ký bởi cả hai bên.
- Chứng minh: hệ thống custom-developed (không phải mua sẵn), bao phủ toàn bộ chức năng OIP, đầu ra phù hợp với Výsledky Diela trong Hợp đồng OR.

---

## 2. Mô hình dữ liệu đề xuất (entity-level, chưa viết DDL đầy đủ)

Tất cả bảng có cột audit chuẩn (`created_by`, `created_on`, `updated_by`, `updated_on`) và PK dạng số qua sequence/identity.

### 2.1. Master data
- **ITEM** — item_id PK, item_code (SKU, unique), item_name, device_category (biometric reader / chip-card reader / monitor / TV / tablet / mobile / e-poster / speaker / digital-signature reader / media player), uom, barcode_value, qr_value, manufacturer, model, is_lot_tracked, min_qty, max_qty, reorder_point, status.
- **SUPPLIER** — supplier_id PK, code, name, contact, integration_ref (cho liên kết kế toán tương lai).
- **CUSTOMER** — customer_id PK, code, name, address, integration_ref (cho liên kết e-shop tương lai).
- **WAREHOUSE** — warehouse_id PK, code, name, address (sẵn sàng multi-site dù hiện tại 1 site).
- **LOCATION** (bin) — location_id PK, warehouse_id FK, zone, aisle, rack, shelf, bin_code, location_type (receiving/pick-face/bulk/quarantine/staging/shipping), capacity_uom, capacity_qty, status.
- **LOT** (batch) — lot_id PK, item_id FK, lot_number, supplier_id FK, manufacture_date, expiry_date, qc_status (pending/passed/failed/hold), unique(item_id, lot_number).

### 2.2. Inventory core
- **INVENTORY_BALANCE** — (item_id, location_id, lot_id) unique, qty_on_hand, qty_allocated, qty_available (derived/view), last_counted_date. → Đáp ứng FR-01 (location+lot) và FR-06 (real-time).
- **INVENTORY_TRANSACTION** (ledger bất biến) — txn_id PK, item_id, location_id, lot_id, txn_type (receipt/putaway/move/pick/pack/ship/adjust/qc_hold/qc_release/count), qty (+/-), txn_ts, source_doc_type, source_doc_id, created_by. Mọi thay đổi tồn kho đều post vào đây — cũng là nguồn dữ liệu chứng minh KPI thời gian/độ chính xác ở Phase 8.
- **STOCK_COUNT** — count_id, location_id, item_id, lot_id, expected_qty, counted_qty, variance, counted_by, counted_on, status.

### 2.3. Inbound
- **INBOUND_RECEIPT** — receipt_id PK, supplier_id FK, po_reference, warehouse_id FK, expected_date, status (expected/receiving/completed/closed), received_by.
- **INBOUND_RECEIPT_LINE** — line_id PK, receipt_id FK, item_id FK, lot_id FK (gán lúc nhận hoặc tạo mới), expected_qty, received_qty, putaway_location_id, qc_status, status.

### 2.4. Outbound
- **OUTBOUND_ORDER** — order_id PK, order_number, customer_id FK, order_source (manual/e-shop-api/edi), order_date, required_ship_date, priority, status (received→allocated→picking→picked→packing→packed→shipped→cancelled — state machine đảm bảo FR-04).
- **OUTBOUND_ORDER_LINE** — line_id PK, order_id FK, item_id FK, qty_ordered, qty_allocated, qty_picked, qty_shipped, lot_id (nullable), status.
- **PICK_WAVE** — wave_id PK, wave_date, status (gom dòng đơn để batch picking/tối ưu tuyến — FR-05).
- **PICK_TASK** — task_id PK, order_line_id FK, wave_id FK, item_id, lot_id, from_location_id, qty_requested, qty_picked, sequence_no (thứ tự tuyến đường theo zone/aisle/rack), assigned_to, status, scanned_code, scan_ts (FR-03).
- **PACKAGE** / **PACKAGE_LINE** — package_id PK, order_id FK, package_type, weight, dimensions, status, packed_by; package_line: package_id FK, order_line_id FK, item_id, lot_id, qty.
- **SHIPMENT** — shipment_id PK, order_id FK, carrier, tracking_number, ship_date, status, ship_from_warehouse_id.

### 2.5. Quality
- **QUALITY_INSPECTION** — inspection_id PK, source_type (inbound_line/lot/return), source_id, item_id, lot_id, inspector, inspection_date, result (pass/fail/conditional), defect_code, notes.
- **QUALITY_HOLD** — hold_id PK, item_id, lot_id, location_id, reason, hold_date, released_by, release_date, status (active/released). Bắt buộc được kiểm tra trong PKG_OUTBOUND (allocation) và PKG_INBOUND (putaway).

### 2.6. Integration (FR-09, framing đúng ở mục 5)
- **INTEGRATION_ENDPOINT_CONFIG** — endpoint_id, system_name (e-shop/accounting), endpoint_url, auth_method reference (secret thật lưu ở APEX workspace credential store), active_flag.
- **INTEGRATION_LOG** (staging/outbox-inbox) — log_id PK, direction (inbound/outbound), integration_type, payload (CLOB/JSON), status (received/processed/error), error_message, related_order_id, created_date. Cho phép retry idempotent + audit trail mà chưa cần hệ thống đối tác thật.

### 2.7. Reporting support
Ưu tiên VIEW hơn bảng vật lý: `V_INVENTORY_CURRENT`, `V_ORDER_CYCLE_TIME`, `V_PICK_ACCURACY`. Chỉ thêm `KPI_SNAPSHOT` nếu cần job `DBMS_SCHEDULER` lưu lịch sử trend cho chart.

### 2.8. Quan hệ chính
`ITEM 1—* LOT`, `ITEM 1—* INVENTORY_BALANCE`, `LOCATION 1—* INVENTORY_BALANCE`, `LOT 1—* INVENTORY_BALANCE`, `INBOUND_RECEIPT 1—* INBOUND_RECEIPT_LINE`, `OUTBOUND_ORDER 1—* OUTBOUND_ORDER_LINE 1—* PICK_TASK`, `PICK_WAVE 1—* PICK_TASK`, `OUTBOUND_ORDER 1—* PACKAGE 1—* PACKAGE_LINE`, `OUTBOUND_ORDER 1—* SHIPMENT`, `LOT/ITEM 1—* QUALITY_INSPECTION/QUALITY_HOLD`; mọi nghiệp vụ thay đổi tồn kho đều post `INVENTORY_TRANSACTION`.

---

## 3. Mapping Module → Page Group → APEXlang template

Bổ sung 7 page group mới vào `page-groups.apx` (hiện chỉ có `administration`): `master-data`, `inventory`, `inbound`, `outbound`, `quality`, `reporting`, `integration`.

| Module | Page group | Trang / Template APEXlang | Ghi chú |
| --- | --- | --- | --- |
| Home / tổng quan vận hành | (page 1) | `page-examples/home-page` → tiến hóa thành `page-examples/dashboard-page` | Metric card khi Phase 5 hoàn thành |
| Danh mục Item/SKU (10k+) | master-data | `page-examples/interactive-grid` (bulk browse/edit), `page-examples/faceted-search` + `region-components/faceted-search`/`smart-filter-search` (tra cứu theo category/status), `page-examples/form-page` (`dialogTemplate: @/drawer` end/right), `items/popup-lov` + `items/select-list` | Faceted search đáp ứng UX "xem real-time theo item" |
| Vị trí/Bin | master-data hoặc inventory | `page-examples/interactive-grid`, `page-examples/form-page` | Cards để trực quan hóa zone (tùy chọn) |
| Lô/Batch | inventory | `page-examples/interactive-report-page` (truy vết), drilldown sang balance |
| Tồn kho real-time (FR-06) | inventory | `page-examples/interactive-grid` + `region-components/faceted-search`, `region-components/chart` | |
| Sổ cái giao dịch tồn kho | inventory | `page-examples/interactive-report-page` (chỉ đọc) | |
| Kiểm kê chu kỳ | inventory | `page-examples/form-page` + `page-examples/interactive-grid` | |
| Phiếu nhập kho (FR-02) | inbound | `page-examples/form-page` header + `region-components/interactive-grid` line (master-detail), `business-logic/processes/form-automatic-row-processing` + `interactive-grid-automatic-row-processing` | |
| Nhận hàng/Putaway có scan | inbound | `page-layout-templates/minimal-no-navigation` hoặc `modal-dialog`, `dynamic-actions/execute-server-side-code` | |
| Đơn hàng ra | outbound | `page-examples/interactive-grid` (hàng đợi), `page-examples/form-page` header + IG line | |
| Pick wave planning | outbound | `page-examples/interactive-grid` | |
| Scan-to-pick (FR-03) | outbound | `page-layout-templates/minimal-no-navigation`/`modal-dialog`, item lớn dễ chạm, JS scan tùy chỉnh, `dynamic-actions/execution-debounce-throttle`, `alert-confirm-cancel`, `show-error-message`/`show-success-message` | |
| Pack confirm | outbound | Tương tự pattern picking | |
| Shipment/manifest | outbound | `page-examples/form-page`, `page-examples/classic-report-page` | |
| Kiểm tra chất lượng | quality | `page-examples/form-page`, `business-logic/dynamic-actions/show-hide-items`, `validations/item` (required có điều kiện) | |
| Hàng đang giữ QC | quality | `page-examples/interactive-grid` | |
| Dashboard KPI (FR-08, FR-10) | reporting | `page-examples/dashboard-page` + `template-components/metric-card` + `region-components/chart`; drilldown qua `interactive-report-page`/`classic-report-page` | |
| Theo dõi tích hợp (FR-09) | integration | `page-examples/interactive-report-page` trên `INTEGRATION_LOG`, `business-logic/processes/invoke-api`, `shared-components/rest-data-sources`, `workspace-components/rest-data-source-servers` + `credentials` | |
| Admin: vai trò/quyền | administration | `shared-components/acl-roles`, `authorizations.apx` | |

**Quy tắc bắt buộc theo workflow APEXlang** (`apexlang/references/workflows/apexlang/workflow-create-app-from-fr-and-model.md`): mọi trang không phải modal phải có breadcrumb entry + region `@breadcrumb`; mọi luồng report→form edit/create phải khai báo modal target có cấu trúc (không chỉ close-refresh dynamic action); master-detail dùng hidden context item + dynamic-action refresh (không reload trang bằng URL).

---

## 4. Danh sách task theo Phase (kèm phân tích)

Mỗi phase liệt kê: mục tiêu, task PL/SQL, task APEXlang/.apx, task JavaScript (nếu có), rủi ro, cách test riêng.

### Phase 0 — Nền tảng & Schema
**Mục tiêu**: dựng nền schema + quy trình generate APEXlang đúng chuẩn trước khi làm bất kỳ trang nào.
- [ ] Viết `application-spec.md` + `.apexlang/app-ux-contract.json` theo `application-spec.template.md` — **bắt buộc trước khi sinh `.apx`** (workflow chặn nếu thiếu).
- [x] DDL bảng lõi cho FR-01 (`SUPPLIER`, `WAREHOUSE`, `LOCATION`, `ITEM`, `LOT`, `INVENTORY_BALANCE` + view `V_INVENTORY_CURRENT`) — `db/ddl/001_fr01_inventory_master.sql`, đã chạy thành công vào DB thật (ADMIN@FREEPDB1, schema parse của app 105), có seed mẫu ở `db/seed/001_fr01_sample_data.sql`. Đã test constraint (unique item_code, unique item+location+lot kể cả khi lot null, check qty_allocated ≤ qty_on_hand, check device_category) — đều chặn đúng dữ liệu sai.
  - ⚠️ Lưu ý phát hiện quan trọng: schema `ADMIN` đã có sẵn một bộ bảng WMS khác theo phong cách Odoo (`PRODUCTS`, `STOCK_LOCATIONS`, `STOCK_LOTS`, `STOCK_QUANTS`, `STOCK_PICKINGS`, `STOCK_MOVES`, `WMS_KPI_METRICS`, `WMS_ERRORS`...) cùng package `INV_PKG` đã có logic thật, và `WMS_KPI_METRICS` đã có sẵn đúng 3 KPI OIP (accuracy 97%, cycle time -25%, error rate -25/30%) làm baseline. Theo yêu cầu người dùng, schema mới (`ITEM`/`LOCATION`/`LOT`...) được thiết kế **song song, độc lập** với bộ bảng cũ đó — không tái sử dụng. Vì constraint name trong Oracle là duy nhất theo schema (không theo bảng), các constraint của bảng `LOT` mới phải đổi prefix từ `LOT_` sang `LOTM_` để tránh đụng `STOCK_LOTS.LOT_PK`.
- [x] DDL bảng ledger (`INVENTORY_TRANSACTION`) — `db/ddl/002_fr01_inventory_transaction.sql`, đã chạy vào DB thật.
- [x] Index: composite `(item_id, location_id, lot_id_key)` trên `INVENTORY_BALANCE` (qua unique constraint), unique index `ITEM(item_code)`, index `ITEM(device_category)`, `ITEM(barcode_value)` — tối ưu cho 10.000+ SKU.
- [x] Package skeleton: `PKG_ITEM`, `PKG_LOCATION`, `PKG_LOT`, `PKG_INVENTORY` (điểm post tồn kho duy nhất — mọi module sau đều gọi qua đây) — `db/plsql/pkg_*.sql`, compile sạch, đã test end-to-end (xem `TASKS.md` mục 3.1).
- [x] Trang APEX cho FR-01 (UI tiếng Anh, có dữ liệu demo) — đã import thật vào app 105 qua `apexctl.mjs runtime roundtrip` (SQLcl `apex validate -input` + `apex import -input`, live check PASS):
  - Page 10 **Items** — Interactive Grid CRUD đầy đủ (add/update/delete inline) trên bảng `ITEM`.
  - Page 20 **Locations** — Interactive Grid CRUD trên bảng `LOCATION`.
  - Page 30 **Lots** — Interactive Report (read-only) join `LOT` + `ITEM`.
  - Page 40 **Inventory Balance** — Interactive Report (read-only) trên view `V_INVENTORY_CURRENT`.
  - Đã thêm page group `master-data`, `inventory`; breadcrumb + navigation menu entry cho cả 4 trang (parent = Home); thêm breadcrumb region còn thiếu ở trang Home.
  - Lưu ý kỹ thuật: `apexctl.mjs runtime validate/roundtrip` khi trỏ `--app-path` vào root repo đôi khi quét nhầm sang app mẫu lồng bên trong (`apexlang/templates/base-app-structure/scaffold-example`) do repo để chung toolkit APEXlang với app thật. Cách xử lý: validate/import từ một bản sao "sạch" (chỉ `application.apx`, `page-groups.apx`, `pages/`, `shared-components/`, `deployments/`, `.apex/`) dựng trong thư mục scratch, rồi đối chiếu `diff -rq` để đảm bảo khớp với repo. Import cần `--workspaceid` tường minh (không chỉ `--db-connection-name`) vì `target_resolution` báo `lookup_scope_workspace_missing` nếu thiếu.
- [x] Mở rộng `page-groups.apx` thêm 7 group (`master-data`, `inventory`, `inbound`, `outbound`, `quality`, `reporting`, `integration`); mở rộng `lists.apx` (nav menu). Còn lại: scaffold `shared-components/acl-roles`, cập nhật `authorizations.apx`, cấu hình `build-options.apx` — để khi có yêu cầu phân quyền cụ thể (Phase 8 hoặc khi có multi-role UAT).
- [ ] **Chụp baseline đo lường hiện trạng thủ công ngay bây giờ** (thời gian xử lý đơn, tỷ lệ lỗi hiện tại) — không thể tái tạo sau này, là dữ liệu gốc cho KPI 25%/25–30% ở Phase 8.
- Loại công việc: PL/SQL (DDL/package) + APEXlang (scaffold) + quy trình (spec/contract).
- Rủi ro: bỏ qua application-spec → các phase sau bị chặn bởi validate; thiếu baseline → không chứng minh được KPI cải thiện.
- Test: `node tools/apexctl.mjs runtime doctor`, `apex validate -input` trên skeleton.

### Phase 1 — Master data & tồn kho real-time (FR-01, FR-06)
- [x] PL/SQL: CRUD API trong `PKG_ITEM`/`PKG_LOCATION`/`PKG_LOT`; view `V_INVENTORY_CURRENT`. (Chiến lược index cho 10k+ SKU đã áp dụng ở Phase 0; sẽ đánh giá lại/partition nếu volume thật tăng vượt dự kiến khi có dữ liệu migration ở Phase 7.)
- [x] APEXlang: catalog Item (IG); Location IG; Lot interactive-report; Inventory balance interactive-report; transaction ledger interactive-report (chỉ đọc). *(Đơn giản hóa so với kế hoạch gốc: dùng Interactive Grid/Report thuần thay vì faceted-search/chart/form-drawer riêng — đủ dùng cho nhu cầu hiện tại, có thể nâng cấp UX sau nếu cần.)*
- [x] JS: không cần ngoài widget chuẩn APEX — đúng như dự kiến.
- Rủi ro: nếu mô hình dữ liệu category thiết bị không khớp thực tế Goldmann → cần review với business trước khi khóa spec.
- Test: compiler-truth audit + `apex validate`; nạp dữ liệu mẫu, smoke-test tra cứu.

### Phase 2 — Nhập kho / Inbound (FR-02)
- [x] PL/SQL: `PKG_INBOUND` (tạo phiếu, nhận dòng vào dock RECEIVING, putaway sang bin đích qua `PKG_INVENTORY.post_transaction`, complete_receipt) — `db/plsql/pkg_inbound.sql`, test end-to-end pass.
- [x] APEXlang: page 60/70 Interactive Grid cho header/line (đơn giản hóa so với master-detail form-page ban đầu — đủ dùng cho nhập liệu kỹ thuật, chưa phải UX vận hành cho nhân viên kho).
- [ ] APEXlang: trang xác nhận nhận/putaway dạng scan (layout tối giản, gọi package qua process thay vì sửa cột trực tiếp) — còn lại.
- [ ] JS: lần đầu cần bắt mã vạch/QR — ưu tiên **keyboard-wedge** (scanner HID gõ như bàn phím vào input ẩn/focus + Enter trigger dynamic action) làm baseline ổn định nhất; camera-based scanning để Phase 3. *(Chưa làm — gắn liền với trang scan ở trên.)*
- Rủi ro: gán lot tự động cần rule rõ ràng (theo PO line hay theo item mới) — cần thống nhất trước khi code `PKG_INBOUND`.
- Test: end-to-end phiếu nhập → tồn kho cập nhật real-time; compiler-truth audit + SQLcl validate.

### Phase 3 — Soạn hàng/scan/đóng gói/tự động hóa đơn hàng/tối ưu vị trí (FR-03, FR-04, FR-05) — **phase nặng JS nhất**
- [x] PL/SQL: `PKG_OUTBOUND` (nhận đơn + allocate theo `INVENTORY_BALANCE`, ưu tiên PICK_FACE > BULK, FEFO theo lô); `PKG_PICKING` (release_wave/assign_wave, confirm_pick sinh pick-task theo `sequence_no` — FR-05, validate scan trước khi post); `PKG_PACKING`; `PKG_SHIPMENT`; state machine trạng thái đơn hàng (received→allocated→picking→picked→packed→shipped) **không có bước thủ công** ngoài gọi API (FR-04) — test end-to-end với dữ liệu thật (đơn SO-DEMO-0001) thành công.
- [x] APEXlang: trang Customers, Outbound Orders, Outbound Order Lines, Pick Tasks (read-only), Shipments — đơn giản hóa so với master-detail form-page ban đầu (dùng Interactive Grid/Report độc lập theo đúng pattern đã dùng ở FR-01/FR-02, chưa làm parent-child context/hidden item refresh).
- [ ] JS (giao phẩm cốt lõi, **còn lại**): keyboard-wedge baseline (input ẩn/focus + Enter trigger gọi `PKG_PICKING.confirm_pick` qua process); camera-based scanning cho picker dùng tablet/mobile không có scanner vật lý; `execution-debounce-throttle` chống double-scan; `alert-confirm-cancel` khi lệch mã. *(`confirm_pick` đã validate scan đúng ở tầng PL/SQL — chỉ còn thiếu UI gọi nó.)*
- [x] Instrumentation: mọi giao dịch tồn kho (RECEIPT/MOVE/PUTAWAY/PICK/SHIP...) đã ghi vào `INVENTORY_TRANSACTION` với timestamp — sẵn sàng nuôi KPI thời gian xử lý đơn ở Phase 8.
- Rủi ro: thuật toán pick-path hiện đơn giản (ưu tiên PICK_FACE, FEFO, sequence theo thứ tự location_id) — đủ đúng chức năng nhưng chưa tối ưu quãng đường di chuyển vật lý; có thể nâng cấp sau nếu cần đo KPI chính xác hơn. Camera-based scanning cần test trên nhiều thiết bị/trình duyệt thực tế của kho — chưa làm.
- Test: end-to-end với dữ liệu thật (không rollback) — order 1 đi hết vòng đời, order 2 dừng ở ALLOCATED đúng kịch bản; compiler-truth audit offline không chạy được trong môi trường này (thiếu runtime jar), SQLcl live validate PASS trên từng batch trang.

### Phase 4 — Quản lý chất lượng (FR-07)
- [x] PL/SQL: `PKG_QUALITY` (`record_inspection` ghi kiểm tra + tự cập nhật `LOT.qc_status`; `place_hold`/`release_hold`); gắn kiểm tra vào `allocate_line` của `PKG_OUTBOUND` (loại trừ lô chưa PASSED + tồn kho đang hold khỏi candidate phân bổ) — test xác nhận đúng, `db/plsql/pkg_quality.sql`.
- [x] APEXlang: IG Quality Inspections, Quality Holds (đơn giản hóa — raw data entry, chưa cascade qc_status tự động qua UI, chỉ qua package).
- Rủi ro đã xử lý: hold check chỉ mới gắn vào `PKG_OUTBOUND.allocate_line` (điểm outbound); chưa cần gắn vào `PKG_INBOUND` vì putaway không cần chặn theo hold (hàng mới nhập chưa qua kiểm tra thì chưa có hold để chặn).
- Test: đã verify non-lot item không hold → allocate OK; lot PENDING → bị loại, sau khi record_inspection PASS → allocate được; hold ACTIVE tại 1 vị trí không ảnh hưởng vị trí khác, release xong lại allocate được.

### Phase 5 — Báo cáo/Dashboard (FR-08, FR-10)
- [x] APEXlang: `dashboard-page` (page 160) với `metric-card` (5 KPI) + `chart` (pie + bar), đọc trực tiếp ITEM/INVENTORY_BALANCE/OUTBOUND_ORDER/PICK_TASK/QUALITY_HOLD/INVENTORY_TRANSACTION, không cần bảng báo cáo riêng ở quy mô hiện tại.
- [ ] PL/SQL: view/materialized view KPI riêng — chưa cần vì dashboard SQL trực tiếp đủ nhanh ở quy mô demo; sẽ làm nếu dữ liệu lớn lên.
- Test: SQL dashboard đã chạy qua live validate; chưa đối chiếu số liệu với business thật (chờ dữ liệu production).

### Phase 6 — Sẵn sàng tích hợp e-shop/kế toán (FR-09, vùng ranh giới)
- [x] PL/SQL: `PKG_INTEGRATION_OUT` (`publish_order_event` build JSON qua APEX_JSON); `PKG_INTEGRATION_IN` (`stage_payload` idempotent qua `idempotency_key`, `apply_order_import` parse JSON → gọi `PKG_OUTBOUND` y hệt luồng manual). Lỗi ghi qua autonomous transaction (`log_error`) nên vẫn có bằng chứng dù transaction chính rollback.
- [x] APEXlang: trang Integration Monitor (page 170, read-only) trên `INTEGRATION_LOG`.
- [ ] `shared-components/rest-data-sources` thật — chưa cấu hình vì chưa có endpoint e-shop/kế toán thật để trỏ tới.
- Test: đơn hợp lệ import + allocate thành công; đơn có item_code sai bị chặn đúng, log ERROR có message, không để lại đơn hàng mồ côi (nhờ rollback ở tầng gọi).
- ⚠️ Lưu ý kỹ thuật quan trọng: autonomous transaction cố update cùng dòng đang bị khóa bởi transaction chính (kể cả do `FOR UPDATE` hay do chính transaction đó `INSERT` dòng đó chưa commit) sẽ tự deadlock (ORA-00060). Do đó `stage_payload` (ghi nhận đã nhận payload) phải tự commit ngay (autonomous), tách biệt hoàn toàn khỏi bước `apply_order_import` xử lý sau.

### Phase 7 — Migration dữ liệu lịch sử (vùng ranh giới)
- [ ] PL/SQL: script migration một lần (SQL*Loader/external table/PL-SQL) nạp dữ liệu cũ vào schema mới.
- [ ] Truy vấn đối chiếu: row count, tổng số lượng, spot-check theo item so sánh dữ liệu cũ vs đã migrate.
- Compliance: lên lịch phase này **ngay trước UAT** để dữ liệu migrated được dùng trực tiếp trong nghiệm thu — củng cố framing "là một phần triển khai/kiểm thử", không phải dịch vụ dữ liệu độc lập.
- Test: đối chiếu 100% số lượng bản ghi + số lượng tồn kho trước/sau migration.

### Phase 8 — Tài liệu, UAT, nghiệm thu
- [ ] Tài liệu kỹ thuật (ERD, package spec, hợp đồng API tích hợp).
- [ ] Hướng dẫn vận hành theo vai trò: nhân viên nhận hàng, picker, packer, QC inspector, supervisor.
- [ ] Sơ đồ quy trình nghiệp vụ (inbound/outbound/quality).
- [ ] Tài liệu onboarding cơ bản (không phải chương trình đào tạo mở rộng).
- [ ] Test case UAT map 1:1 với FR-01..FR-10.
- [ ] Đo 3 KPI theo phương pháp ở mục 6.
- [ ] Compiler-truth audit + `apex validate` + import toàn app trước bàn giao.
- [ ] Ký Preberací protokol.

---

## 5. Rào chắn tuân thủ (compliance guardrails)

- **Traceability**: mọi task ở mục 4 phải map được với 1 trong FR-01..FR-10; task nào không map được → gắn cờ loại bỏ trước khi triển khai (duy trì bảng đối chiếu sống cạnh `application-spec.md`).
- **Không mua sắm**: không có dòng nào trong kế hoạch/ngân sách được phép bao gồm mua/license WMS thương mại hoặc phần cứng (scanner/server/thiết bị). "Hỗ trợ scan mã vạch/QR" = tích hợp phần mềm trên phần cứng có sẵn/BYO + camera API trình duyệt — **không bao giờ** là dòng chi phí mua thiết bị.
- **Không có module ngoài phạm vi**: loại trừ tường minh CRM, HR/chấm công, hóa đơn, marketing/quảng bá, phân tích thị trường/đối thủ, phân tích tài chính/chi phí khỏi mô hình dữ liệu và page group ở trên. Yêu cầu thêm các mục này trong lúc build phải được coi là thay đổi phạm vi cần phê duyệt riêng, không thuộc WMS này.
- **Không làm website**: chỉ xây API/integration points và bảng staging bên trong WMS; không xây/restyle site e-shop công khai.
- **Framing đúng cho vùng ranh giới**:
  - Tích hợp (Phase 6): trình bày là "kiến trúc tích hợp WMS lõi", không tách dự án riêng.
  - Migration dữ liệu (Phase 7): trình bày là một phần triển khai/kiểm thử, lên lịch sát UAT.
  - Tài liệu (Phase 8): chỉ khai là đầu ra tài liệu kỹ thuật/hướng dẫn vận hành/sơ đồ quy trình — đúng phạm vi OR Contract yêu cầu.
- **Không bảo trì sau bàn giao**: Phase 8 nghiệm thu là điểm kết thúc phạm vi tính phí; sửa lỗi sau nghiệm thu là bảo hành (warranty), không phải bảo trì định kỳ.
- **Đào tạo**: giới hạn ở hướng dẫn sử dụng cơ bản + 1 buổi/vai trò, không lên chương trình đào tạo định kỳ.
- **Mốc thời gian**: mọi timeline/milestone/bằng chứng billing phải **≥ 1/6/2026** (ngày hiệu lực tài trợ); Phase 0 kickoff và mọi bằng chứng billing không được trước ngày này.

---

## 6. Kiểm thử / Verify

### 6.1. Lớp APEXlang (mỗi unit và mỗi phase)
- Trong lúc soạn: kiểm tra syntax/property/reference/placeholder cục bộ theo từng unit.
- Sau khi gộp hết unit của 1 phase: 1 lần local integration validation + 1 lần compiler-truth audit (`compiler-truth-report.json`) — bắt buộc trước khi validate live.
- Validate live mỗi phase: `node tools/apexctl.mjs runtime validate --app-path <path> --db-connection-name <conn>` (chạy `apex validate -input`); `apex import -input` chỉ chạy sau khi có lựa chọn "Check and import" tường minh, cùng phiên SQLcl đã authenticate.

### 6.2. Lớp PL/SQL (không được APEXlang validate cover)
- Bộ test riêng (utPLSQL hoặc SQLcl script harness, đặt ở `db/tests`) cho: post transaction đúng, logic allocation, sinh pick-path, enforcement QC hold, idempotency staging tích hợp.
- Chạy song song, cùng nhịp với vòng validate APEXlang — không thay thế nó.

### 6.3. UAT theo 3 KPI bắt buộc (FR-10)
- **Độ chính xác ≥ 97%**: đếm song song (system vs vật lý) trên tập location/item thí điểm; accuracy = 1 − (variance qty / counted qty).
- **Giảm thời gian xử lý đơn ≥ 25%**: dùng baseline thủ công chụp ở Phase 0 so với timestamp instrumented ở Phase 3 (received→allocated→picked→packed→shipped) trong đợt chạy thí điểm.
- **Giảm chi phí/lỗi 25–30%**: theo dõi sự kiện lỗi (sửa mis-pick, mis-ship, adjustment do lỗi) và giờ công trước/sau nếu có số liệu.
- Mỗi hạng mục FR-01..FR-10 có ít nhất 1 test case UAT ghi pass/fail — làm bằng chứng cho Preberací protokol.

---

## 7. File/thư mục liên quan trong dự án

- `application.apx` — cấu hình app 26HOUSE.
- `page-groups.apx` — cần bổ sung 7 page group ở mục 3.
- `shared-components/lists.apx`, `authorizations.apx` — cần mở rộng nav menu + phân quyền theo module.
- `apexlang/references/workflows/apexlang/workflow-create-app-from-fr-and-model.md` — quy trình bắt buộc khi sinh `.apx`.
- `apexlang/references/workflows/apexlang/application-spec.template.md` — template spec phải hoàn thành trước khi sinh trang (Phase 0).
- `apexlang/templates/` — kho template page/region/business-logic dùng cho mục 3.
