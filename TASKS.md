# TASKS.md — Việc cần làm tiếp theo (WMS 26house)

> File này là danh sách công việc để tiếp tục dự án qua nhiều phiên làm việc. Xem `PROJECT-PLAN.md` để biết bối cảnh đầy đủ (mô hình dữ liệu, mapping module, rào chắn tuân thủ) và `CLAUDE.md` để biết quy ước/rule khi code tiếp.
> Cập nhật lần cuối: 2026-09-17.

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
| FR-02 | Nhập kho tự động | 🟢 Hoàn thành (kể cả UI thao tác) | Bảng `INBOUND_RECEIPT`, `INBOUND_RECEIPT_LINE`; package `PKG_INBOUND` (`create_receipt`/`add_line`/`add_or_increment_line`/`receive_line`/`putaway_line`/`complete_receipt`). Trang Inbound Receipt Detail (page 61, full page riêng, tách khỏi Inbound Receipts page 60 dạng Interactive Report danh sách): trạng thái mặc định EXPECTED khi tạo, ẩn dòng/Quick Add cho tới khi có receipt_id, ô Quick Add quét/gõ mã item tự thêm dòng (tăng qty nếu dòng PENDING đã có), nút **Confirm** gọi `receive_line`/`putaway_line` qua process (không sửa cột trực tiếp), nút **Done** gọi `complete_receipt`. Đã import và test trên server remote |
| FR-03 | Soạn hàng có scan | 🟢 Hoàn thành (kể cả UI scan) | `PICK_TASK.scanned_code/scan_ts` + `PKG_PICKING.confirm_pick` validate đúng barcode/QR trước khi cho pick, post đúng giao dịch tồn kho. Trang Pick Tasks (110) đã có panel "Scan to Pick": chọn task từ dropdown (chỉ liệt kê task PENDING/ASSIGNED/IN_PROGRESS), nhập Qty Picked, quét/gõ mã rồi Enter → gọi `PKG_PICKING.confirm_pick` qua Dynamic Action (không sửa cột trực tiếp), báo lỗi rõ ràng khi quét sai mã hoặc vượt số lượng. **Đã phát hiện + sửa 1 bug thật khi smoke-test tính năng này**: `confirm_pick` kiểm tra mã quét bằng `NOT IN (barcode, qr)` — khi `qr_value` null (đa số item chỉ có barcode), biểu thức này luôn là NULL/unknown trong PL/SQL (không phải TRUE), nên **mọi mã quét sai đều lọt qua mà không bị chặn**. Đã sửa bằng điều kiện OR/AND tường minh xử lý đúng NULL, test lại xác nhận đúng (mã sai bị chặn, mã đúng được chấp nhận), compile sạch + verify trên cả `admin_freepdb1` và `wms_remote` |
| FR-04 | Tự động hóa đơn hàng end-to-end | 🟢 Hoàn thành (kể cả UI Pack/Ship) | `OUTBOUND_ORDER/OUTBOUND_ORDER_LINE/SHIP_PACKAGE*/SHIPMENT` + package `PKG_OUTBOUND/PKG_PICKING/PKG_PACKING/PKG_SHIPMENT` chạy trọn vòng đời received→allocated→picking→picked→packed→shipped. Outbound Orders tách theo đúng mẫu Inbound Receipts: **Outbound Orders (page 90)** nay là Interactive Report danh sách (click 1 dòng → mở chi tiết), **Outbound Order Detail (page 91, mới)** gộp header + dòng (trước ở page riêng "Outbound Order Lines", page 100, nay đã xóa/gộp vào 91) trên cùng 1 trang, có nút **Pack Order** (hiện khi status=PICKED, gọi `PKG_PACKING.pack_order`) và **Ship Order** (hiện khi status=PACKED, kèm ô Carrier/Tracking tùy chọn, gọi `PKG_SHIPMENT.ship_order`) — cả hai qua process `executeCode`, không thao tác cột trực tiếp. Trang Shipments (120) trở lại thành report read-only thuần (chỉ xem shipment đã tạo). 5 trang APEX (Customers, Outbound Orders, Outbound Order Detail, Pick Tasks, Shipments) |
| FR-05 | Tối ưu vị trí/tuyến đường | 🟡 Cơ bản | `PKG_OUTBOUND.allocate_line` ưu tiên PICK_FACE trước BULK, FEFO theo hạn dùng trong cùng vị trí, `PICK_TASK.sequence_no` định thứ tự lấy hàng. Đơn giản hóa theo đúng quyết định trong PROJECT-PLAN.md (không làm TSP tối ưu tuyệt đối) |
| FR-06 | Tồn kho real-time | 🟢 Đáp ứng ở mức FR-01 | View `V_INVENTORY_CURRENT`, trang Inventory Balance, và trang Inventory Transactions (ledger, có PKG_INVENTORY ghi mọi thay đổi) đã có đủ. Sẽ được dùng lại nguyên vẹn khi Inbound/Outbound (FR-02..FR-05) post giao dịch qua `PKG_INVENTORY` |
| FR-07 | Quản lý chất lượng | 🟢 Core hoàn thành (Hold/Release có UI, Inspection chưa) | Bảng `QUALITY_INSPECTION`, `QUALITY_HOLD`; package `PKG_QUALITY` (`record_inspection` tự cập nhật `LOT.qc_status` qua `PKG_LOT`, `place_hold`/`release_hold`). Đã gắn kiểm tra vào `PKG_OUTBOUND.allocate_line`: loại trừ lô chưa PASSED và tồn kho đang bị hold khỏi candidate phân bổ — test xác nhận đúng. Trang Quality Holds (150) nay là read-only report + 2 panel: **Place Hold** (chọn Item/Lot tùy chọn/Location tùy chọn + Reason, gọi `place_hold`) và **Release Hold** (chọn 1 hold ACTIVE từ dropdown, gọi `release_hold`) — không còn sửa trực tiếp bảng `QUALITY_HOLD` qua Interactive Grid. **Còn thiếu**: trang Quality Inspections (140) vẫn là Interactive Grid raw insert, chưa gọi `record_inspection`. **Giới hạn đã biết**: txn_type `QC_HOLD`/`QC_RELEASE` trong enum `INVENTORY_TRANSACTION` chưa từng được post — vì đặt/gỡ hold không đổi `qty_on_hand`, còn `PKG_INVENTORY.post_transaction` luôn cộng dồn vào balance (và bảng có constraint `qty <> 0`), nên post một dòng "giữ chỗ" qua cơ chế đó sẽ làm sai lệch tồn kho; cần thiết kế riêng (bảng log không ảnh hưởng balance) nếu muốn có audit trail cho hành động hold/release, chưa làm trong phiên này |
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
- [x] Trang APEX: Inbound Receipts (page 60) — Interactive Grid Master-Detail (header + dòng trên cùng 1 trang), đã import vào app 105.
- [x] Trang xác nhận nhận hàng/putaway (Inbound Receipt Detail, page 61): trạng thái mặc định EXPECTED, ẩn dòng/Quick Add tới khi có receipt_id, Quick Add quét/gõ mã item tự thêm dòng (tăng qty nếu đã tồn tại), nút Confirm gọi `receive_line`/`putaway_line`, nút Done gọi `complete_receipt` — qua process, không sửa cột trực tiếp. **Đã xong, việc còn lại duy nhất của FR-02.**

### 3.3. Phase 3 — Outbound/Picking/Scan (FR-03, FR-04, FR-05)
- [x] Bảng `CUSTOMER`, `OUTBOUND_ORDER`, `OUTBOUND_ORDER_LINE`, `PICK_WAVE`, `PICK_TASK`, `SHIP_PACKAGE`, `SHIP_PACKAGE_LINE` (đổi tên tránh từ khóa `PACKAGE`), `SHIPMENT` — `db/ddl/004_fr03_customer.sql`, `db/ddl/005_fr03_outbound.sql`.
- [x] `PKG_OUTBOUND` (create_order/add_line/allocate_line/allocate_order/cancel_order — ưu tiên PICK_FACE > BULK, FEFO theo lô), `PKG_PICKING` (release_wave/assign_wave/confirm_pick — validate scan trước khi post giao dịch), `PKG_PACKING` (pack_order), `PKG_SHIPMENT` (ship_order) — tất cả trong `db/plsql/`. Đã thêm `PKG_INVENTORY.get_location_by_type` dùng chung (refactor luôn `PKG_INBOUND` để gọi lại thay vì trùng code).
- [x] Test end-to-end **với dữ liệu thật, không rollback** (đơn SO-DEMO-0001): received→allocated→picking→picked→packed→shipped, đúng transaction MOVE/PICK/SHIP, đúng tồn kho cuối. Đơn SO-DEMO-0002 dừng ở ALLOCATED để demo trạng thái giữa chừng.
- [x] Trang APEX: Customers (80), Outbound Orders (90), Outbound Order Lines (100), Pick Tasks (110, **read-only** vì phải qua `PKG_PICKING.confirm_pick` mới đúng), Shipments (120) — đã import vào app 105.
- [x] Trang scan-to-pick: panel "Scan to Pick" trên Pick Tasks (110) — chọn task từ dropdown, nhập Qty Picked, quét/gõ mã rồi Enter (Dynamic Action) gọi `PKG_PICKING.confirm_pick`. **Đã xong, việc còn lại của FR-03.** Phát hiện + sửa kèm 1 bug thật trong `confirm_pick` khi smoke-test (xem mục 2, dòng FR-03).
- [x] Tách Outbound Orders theo mẫu Inbound Receipts: page 90 (danh sách, Interactive Report) + page 91 mới "Outbound Order Detail" (header + dòng, gộp luôn page 100 "Outbound Order Lines" cũ — đã xóa). Nút Pack Order/Ship Order chuyển vào page 91 (điều kiện theo STATUS của đơn), gọi `PKG_PACKING.pack_order`/`PKG_SHIPMENT.ship_order`; Shipments (120) trở lại report read-only thuần — đóng nốt phần UI thao tác của FR-04.
- [ ] Trang quản lý Pick Wave / Ship Package riêng (hiện chưa có UI, chỉ có qua PL/SQL) — có thể bổ sung sau nếu cần thao tác thủ công qua UI thay vì gọi API trực tiếp.

### 3.4. Phase 4 — Quality (FR-07) ✅ core xong
- [x] Bảng + `PKG_QUALITY` + tích hợp vào `PKG_OUTBOUND.allocate_line` — xem mục 2.
- [x] Panel Place Hold / Release Hold trên Quality Holds (150), gọi `PKG_QUALITY.place_hold`/`release_hold` qua process — không còn sửa trực tiếp bảng `QUALITY_HOLD` qua Interactive Grid.
- [ ] Trang "action" cho inspection (gọi `PKG_QUALITY.record_inspection` để tự cập nhật qc_status, thay vì IG raw insert hiện tại không cascade) — chưa làm, còn lại của FR-07.
- [ ] Cân nhắc thiết kế bảng log riêng cho `QC_HOLD`/`QC_RELEASE` nếu cần audit trail — không post qua `PKG_INVENTORY.post_transaction` (xem giới hạn đã biết ở mục 2, dòng FR-07).

### 3.5. Phase 5 — Reporting/Dashboard (FR-08) ✅ core xong
- [x] Trang Operations Dashboard (page 160) — xem mục 2.
- [ ] Bổ sung thêm biểu đồ/metric khi có thêm dữ liệu thật (vd accuracy theo `WMS_STOCKTAKES`-style cycle count nếu làm sau).

### 3.6. Phase 6 — Integration (FR-09) ✅ core xong
- [x] Bảng + `PKG_INTEGRATION_OUT`/`PKG_INTEGRATION_IN` + trang Integration Monitor — xem mục 2.
- [ ] Cấu hình `INTEGRATION_ENDPOINT_CONFIG` thật + `shared-components/rest-data-sources` khi có endpoint e-shop/kế toán thật để gọi (hiện chỉ có bảng cấu hình, chưa có REST data source nào trong APEX).

### 3.7. Phase 3 còn lại — UI scan-to-pick (FR-03) ✅ xong
- [x] Trang scan-to-pick (keyboard-wedge) gọi `PKG_PICKING.confirm_pick` — đã hoãn lại trước đó theo yêu cầu người dùng để làm FR-07/08/09 trước, nay đã quay lại làm xong (xem mục 3.3).

### 3.8. Các phase còn lại
Phase 7 (Migration), Phase 8 (UAT/nghiệm thu) — xem chi tiết trong `PROJECT-PLAN.md` mục 4, chưa bắt đầu.

## 4. Quy tắc khi cập nhật file này

- Khi hoàn thành 1 task, đổi `[ ]` → `[x]` và cập nhật lại bảng trạng thái ở mục 2.
- Khi phát hiện yêu cầu mới/thay đổi từ tài liệu nguồn, cập nhật `PROJECT-PLAN.md` mục 1 trước, sau đó mới thêm task vào đây.
- Task mới phát sinh ngoài kế hoạch (bugfix, refactor nhỏ) có thể thêm thẳng vào mục 3 tương ứng theo phase, không cần tạo mục riêng.
