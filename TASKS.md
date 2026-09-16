# TASKS.md — Việc cần làm tiếp theo (WMS 26house)

> File này là danh sách công việc để tiếp tục dự án qua nhiều phiên làm việc. Xem `PROJECT-PLAN.md` để biết bối cảnh đầy đủ (mô hình dữ liệu, mapping module, rào chắn tuân thủ) và `CLAUDE.md` để biết quy ước/rule khi code tiếp.
> Cập nhật lần cuối: 2026-09-16.

## 1. Kết quả đối chiếu tài liệu nguồn (docx)

Đã đọc lại toàn bộ `26house-new-system.docx` (57 đoạn văn + 1 bảng "Hoạt động bị cấm") và đối chiếu với `PROJECT-PLAN.md`. **Không phát hiện yêu cầu nào bị thiếu**:
- 10 hạng mục bắt buộc (FR-01..FR-10) — đã có đủ ở mục 1.1.
- Bảng 10 hoạt động bị cấm — đã có đủ ở mục 1.2 (khớp 100% với bảng gốc trong docx).
- 3 vùng ranh giới (tích hợp, migration, tài liệu) — đã có đủ ở mục 1.3.
- Đầu ra bắt buộc cho Báo cáo cuối cùng — đã có đủ ở mục 1.4.

Việc còn thiếu **không phải ở tài liệu yêu cầu, mà ở tiến độ triển khai** — xem bảng dưới.

## 2. Ma trận trạng thái triển khai theo FR

| FR | Hạng mục | Trạng thái | Đã có gì |
| --- | --- | --- | --- |
| FR-01 | CSDL tập trung tồn kho (item/vị trí/lô) | 🟢 Hoàn thành (schema+API+UI) | Bảng `SUPPLIER/WAREHOUSE/LOCATION/ITEM/LOT/UOM/INVENTORY_BALANCE/INVENTORY_TRANSACTION` + view `V_INVENTORY_CURRENT` trong DB thật, có seed data. Package `PKG_ITEM/PKG_LOCATION/PKG_LOT/PKG_INVENTORY` đã compile sạch, đã test end-to-end. Trang Items/Locations vẫn là 1 Interactive Grid duy nhất (đúng chuẩn UX với các trang khác), cột many2one (UOM, Warehouse) là dropdown thật lọc theo `is_active='Y'` ngay trong lưới, cột boolean là checkbox thật (xem `CLAUDE.md` — `lov{}`/`checkbox` dùng được trên cột Interactive Grid, ban đầu tưởng không được do local lint báo sai). Thêm 2 trang mới Warehouses/Suppliers (trước đây chưa có UI quản lý). 8 trang APEX master data (Items, Locations, Lots, UOM, Warehouses, Suppliers, Inventory Balance, Inventory Transactions) đã import vào app 105. **Còn thiếu duy nhất**: baseline KPI thủ công (cần số liệu thật từ người dùng/business, không thể tự tạo) |
| FR-02 | Nhập kho tự động | 🟢 Core hoàn thành | Bảng `INBOUND_RECEIPT`, `INBOUND_RECEIPT_LINE`; package `PKG_INBOUND` (`create_receipt`/`add_line`/`receive_line`/`putaway_line`/`complete_receipt`) — đã test end-to-end (nhận hàng vào dock RECEIVING → putaway sang bin → complete, đều post đúng qua `PKG_INVENTORY`). 2 trang APEX (Inbound Receipts, Inbound Receipt Lines) là Interactive Grid với Supplier/Warehouse/Item/Lot/Location là dropdown thật ngay trong lưới. **Còn thiếu**: trang thao tác "Receive & Putaway" dạng scan (khác với CRUD hiện có, cần cho UX vận hành thực tế của nhân viên kho) |
| FR-03 | Soạn hàng có scan | 🟡 Backend xong, UI scan chưa có | `PICK_TASK.scanned_code/scan_ts` + `PKG_PICKING.confirm_pick` đã validate đúng barcode/QR (`item.barcode_value`/`qr_value`) trước khi cho phép pick, post đúng giao dịch tồn kho. Trang Pick Tasks (110) chỉ đọc, **chưa có trang scan thao tác** (keyboard-wedge) — đây là việc còn lại của FR-03 |
| FR-04 | Tự động hóa đơn hàng end-to-end | 🟢 Core hoàn thành | `OUTBOUND_ORDER/OUTBOUND_ORDER_LINE/SHIP_PACKAGE*/SHIPMENT` + package `PKG_OUTBOUND/PKG_PICKING/PKG_PACKING/PKG_SHIPMENT` chạy trọn vòng đời received→allocated→picking→picked→packed→shipped **không thao tác thủ công nào ngoài gọi API** — test end-to-end với đơn demo SO-DEMO-0001 (thật, không rollback) thành công. 5 trang APEX (Customers, Outbound Orders, Order Lines, Pick Tasks, Shipments); Orders/Order Lines là Interactive Grid với Customer/Warehouse/Item là dropdown thật ngay trong lưới |
| FR-05 | Tối ưu vị trí/tuyến đường | 🟡 Cơ bản | `PKG_OUTBOUND.allocate_line` ưu tiên PICK_FACE trước BULK, FEFO theo hạn dùng trong cùng vị trí, `PICK_TASK.sequence_no` định thứ tự lấy hàng. Đơn giản hóa theo đúng quyết định trong PROJECT-PLAN.md (không làm TSP tối ưu tuyệt đối) |
| FR-06 | Tồn kho real-time | 🟢 Đáp ứng ở mức FR-01 | View `V_INVENTORY_CURRENT`, trang Inventory Balance, và trang Inventory Transactions (ledger, có PKG_INVENTORY ghi mọi thay đổi) đã có đủ. Sẽ được dùng lại nguyên vẹn khi Inbound/Outbound (FR-02..FR-05) post giao dịch qua `PKG_INVENTORY` |
| FR-07 | Quản lý chất lượng | 🟢 Core hoàn thành | Bảng `QUALITY_INSPECTION`, `QUALITY_HOLD`; package `PKG_QUALITY` (`record_inspection` tự cập nhật `LOT.qc_status` qua `PKG_LOT`, `place_hold`/`release_hold`). Đã gắn kiểm tra vào `PKG_OUTBOUND.allocate_line`: loại trừ lô chưa PASSED và tồn kho đang bị hold khỏi candidate phân bổ — test xác nhận đúng. 2 trang APEX (Quality Inspections, Quality Holds) |
| FR-08 | Báo cáo/Dashboard | 🟢 Core hoàn thành | Trang Operations Dashboard (page 160): 5 metric card (Active Items, Total On-Hand Qty, Open Outbound Orders, Pending Pick Tasks, Active Quality Holds) + 2 chart (Orders by Status - pie, Inventory Transactions by Type - bar), đọc trực tiếp từ dữ liệu hiện có, không cần bảng báo cáo riêng |
| FR-09 | Sẵn sàng tích hợp e-shop/kế toán | 🟢 Core hoàn thành | Bảng `INTEGRATION_ENDPOINT_CONFIG`, `INTEGRATION_LOG` (có `idempotency_key` chống xử lý trùng); package `PKG_INTEGRATION_OUT` (publish_order_event, build JSON qua APEX_JSON), `PKG_INTEGRATION_IN` (stage_payload idempotent + apply_order_import parse JSON → tạo đơn qua `PKG_OUTBOUND`, lỗi được ghi nhận qua autonomous transaction). Test end-to-end: đơn hợp lệ tạo thành công, đơn lỗi (item_code sai) bị chặn đúng và ghi log ERROR có message rõ ràng. Trang Integration Monitor (page 170, read-only) |
| FR-10 | KPI đo lường (97% / -25% / -25~30%) | 🟡 Placeholder | Bảng `KPI_BASELINE` đã tạo, có 3 dòng dữ liệu **GIẢ ĐỊNH** (`IS_PLACEHOLDER='Y'`, ghi rõ trong `BASELINE_NOTE`) để demo/phát triển — **phải thay bằng số liệu đo thật trước khi UAT/nộp báo cáo SIEA**, nếu không sẽ không chứng minh được mức cải thiện theo đúng cảnh báo trong docx gốc. Trang KPI Baseline (130) đã import, sửa được trực tiếp khi có số liệu thật. `INVENTORY_TRANSACTION` đã sẵn sàng làm nguồn đo lường tự động sau này |

Chú thích: ⚪ Chưa làm · 🟡 Đang làm/một phần · 🟢 Hoàn thành và đã test

## 3. Task ưu tiên tiếp theo (theo thứ tự nên làm)

### 3.1. Hoàn thiện nốt Phase 0/FR-01 (ưu tiên cao nhất — làm trước khi sang FR-02)
- [x] Viết `PKG_ITEM` — CRUD (`create_item`/`update_item`/`set_status`). File: `db/plsql/pkg_item.sql`.
- [x] Viết `PKG_LOCATION` — CRUD (`create_location`/`update_location`/`set_active`). File: `db/plsql/pkg_location.sql`.
- [x] Viết `PKG_LOT` — CRUD + enforce qc_status transition hợp lệ (PENDING → PASSED/FAILED/HOLD, HOLD → PASSED/FAILED). File: `db/plsql/pkg_lot.sql`.
- [x] Tạo bảng `INVENTORY_TRANSACTION` (ledger bất biến). File: `db/ddl/002_fr01_inventory_transaction.sql`.
- [x] Viết `PKG_INVENTORY` — điểm post duy nhất cho mọi thay đổi `INVENTORY_BALANCE` (`post_transaction`/`allocate`/`release_allocation`/`qty_on_hand`/`qty_available`), luôn ghi kèm 1 dòng `INVENTORY_TRANSACTION`, chặn âm kho bằng lỗi rõ ràng (ORA-20001). File: `db/plsql/pkg_inventory.sql`. Đã test end-to-end (receipt → allocate → pick → release, và over-pick bị chặn đúng).
- [x] Trang APEX Inventory Transactions (page 50, Interactive Report read-only) — đã import vào app 105.
- [x] Mở rộng `page-groups.apx` thêm 5 group còn thiếu: `inbound`, `outbound`, `quality`, `reporting`, `integration`.
- [x] Baseline KPI (FR-10) — theo yêu cầu người dùng, dùng **dữ liệu giả định** thay vì số liệu thật. Bảng `KPI_BASELINE` + seed 3 dòng `IS_PLACEHOLDER='Y'` — `db/ddl/006_fr10_kpi_baseline.sql`, `db/seed/003_fr10_kpi_baseline_placeholder.sql`. Trang KPI Baseline (page 130) đã import. ⚠️ **Phải thay bằng số liệu đo thật trước khi UAT/nộp báo cáo SIEA** (đặt `is_placeholder='N'` sau khi cập nhật).

### 3.2. Phase 2 — Inbound (FR-02)
- [x] Thiết kế + tạo bảng `INBOUND_RECEIPT`, `INBOUND_RECEIPT_LINE` — `db/ddl/003_fr02_inbound.sql`.
- [x] Viết `PKG_INBOUND` (tạo phiếu, nhận dòng vào dock RECEIVING, putaway sang bin đích, complete_receipt) — `db/plsql/pkg_inbound.sql`. Đã test end-to-end qua SQL, rollback sạch.
- [x] Trang APEX: Inbound Receipts (page 60), Inbound Receipt Lines (page 70) — Interactive Grid CRUD, đã import vào app 105.
- [ ] Trang xác nhận nhận hàng/putaway dạng scan (layout tối giản, gọi `PKG_INBOUND.receive_line`/`putaway_line` qua process thay vì sửa cột trực tiếp) — keyboard-wedge trước, camera-based để Phase 3. **Việc còn lại duy nhất của FR-02.**

### 3.3. Phase 3 — Outbound/Picking/Scan (FR-03, FR-04, FR-05)
- [x] Bảng `CUSTOMER`, `OUTBOUND_ORDER`, `OUTBOUND_ORDER_LINE`, `PICK_WAVE`, `PICK_TASK`, `SHIP_PACKAGE`, `SHIP_PACKAGE_LINE` (đổi tên tránh từ khóa `PACKAGE`), `SHIPMENT` — `db/ddl/004_fr03_customer.sql`, `db/ddl/005_fr03_outbound.sql`.
- [x] `PKG_OUTBOUND` (create_order/add_line/allocate_line/allocate_order/cancel_order — ưu tiên PICK_FACE > BULK, FEFO theo lô), `PKG_PICKING` (release_wave/assign_wave/confirm_pick — validate scan trước khi post giao dịch), `PKG_PACKING` (pack_order), `PKG_SHIPMENT` (ship_order) — tất cả trong `db/plsql/`. Đã thêm `PKG_INVENTORY.get_location_by_type` dùng chung (refactor luôn `PKG_INBOUND` để gọi lại thay vì trùng code).
- [x] Test end-to-end **với dữ liệu thật, không rollback** (đơn SO-DEMO-0001): received→allocated→picking→picked→packed→shipped, đúng transaction MOVE/PICK/SHIP, đúng tồn kho cuối. Đơn SO-DEMO-0002 dừng ở ALLOCATED để demo trạng thái giữa chừng.
- [x] Trang APEX: Customers (80), Outbound Orders (90), Outbound Order Lines (100), Pick Tasks (110, **read-only** vì phải qua `PKG_PICKING.confirm_pick` mới đúng), Shipments (120) — đã import vào app 105.
- [ ] JS scan: **việc còn lại của FR-03** — trang thao tác scan-to-pick (keyboard-wedge trước: input ẩn/focus + Enter trigger gọi `PKG_PICKING.confirm_pick`; camera-based scanning sau). Hiện `confirm_pick` đã sẵn sàng nhận `p_scanned_code`, chỉ còn thiếu UI gọi nó.
- [ ] Trang quản lý Pick Wave / Ship Package riêng (hiện chưa có UI, chỉ có qua PL/SQL) — có thể bổ sung sau nếu cần thao tác thủ công qua UI thay vì gọi API trực tiếp.

### 3.4. Phase 4 — Quality (FR-07) ✅ core xong
- [x] Bảng + `PKG_QUALITY` + tích hợp vào `PKG_OUTBOUND.allocate_line` — xem mục 2.
- [ ] Trang "action" cho inspection (gọi `PKG_QUALITY.record_inspection` để tự cập nhật qc_status, thay vì IG raw insert hiện tại không cascade) — có thể làm sau nếu cần UX tốt hơn.

### 3.5. Phase 5 — Reporting/Dashboard (FR-08) ✅ core xong
- [x] Trang Operations Dashboard (page 160) — xem mục 2.
- [ ] Bổ sung thêm biểu đồ/metric khi có thêm dữ liệu thật (vd accuracy theo `WMS_STOCKTAKES`-style cycle count nếu làm sau).

### 3.6. Phase 6 — Integration (FR-09) ✅ core xong
- [x] Bảng + `PKG_INTEGRATION_OUT`/`PKG_INTEGRATION_IN` + trang Integration Monitor — xem mục 2.
- [ ] Cấu hình `INTEGRATION_ENDPOINT_CONFIG` thật + `shared-components/rest-data-sources` khi có endpoint e-shop/kế toán thật để gọi (hiện chỉ có bảng cấu hình, chưa có REST data source nào trong APEX).

### 3.7. Phase 3 còn lại — UI scan-to-pick (FR-03)
- [ ] Trang scan-to-pick (keyboard-wedge) gọi `PKG_PICKING.confirm_pick` — đã hoãn lại để làm FR-07/08/09 trước theo yêu cầu người dùng, cần quay lại làm tiếp.

### 3.8. Các phase còn lại
Phase 7 (Migration), Phase 8 (UAT/nghiệm thu) — xem chi tiết trong `PROJECT-PLAN.md` mục 4, chưa bắt đầu.

## 4. Quy tắc khi cập nhật file này

- Khi hoàn thành 1 task, đổi `[ ]` → `[x]` và cập nhật lại bảng trạng thái ở mục 2.
- Khi phát hiện yêu cầu mới/thay đổi từ tài liệu nguồn, cập nhật `PROJECT-PLAN.md` mục 1 trước, sau đó mới thêm task vào đây.
- Task mới phát sinh ngoài kế hoạch (bugfix, refactor nhỏ) có thể thêm thẳng vào mục 3 tương ứng theo phase, không cần tạo mục riêng.
