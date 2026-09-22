# 26house — Hệ thống WMS (Oracle APEX + APEXlang + PL/SQL)

Hệ thống quản lý kho (WMS) custom-developed cho công ty Goldmann, tài trợ bởi SIEA (Slovakia). Yêu cầu nghiệp vụ gốc nằm ở [`26house-new-system.docx`](26house-new-system.docx), kế hoạch tổng ở [`PROJECT-PLAN.md`](PROJECT-PLAN.md), trạng thái triển khai/task cần làm tiếp ở [`TASKS.md`](TASKS.md), quy ước kỹ thuật + các lỗi/gotcha đã gặp thực tế ở [`CLAUDE.md`](CLAUDE.md).

File này chỉ tập trung vào: **cách cài đặt môi trường và import dữ liệu** — không lặp lại nội dung nghiệp vụ đã có ở 3 file trên.

## 1. Kiến trúc

- **Ứng dụng**: Oracle APEX, app id **105**, alias `26HOUSE`, workspace `tdt203`.
- **Schema DB**: `ADMIN` trên Oracle 26ai Free (schema này còn chứa các bảng của các dự án demo khác từ trước — xem cảnh báo trùng tên constraint trong `CLAUDE.md`).
- **DSL sinh trang APEX**: [APEXlang](apexlang/) — file `.apx` trong [`pages/`](pages/) và [`shared-components/`](shared-components/) được compile/import vào DB thật qua `node apexlang/tools/apexctl.mjs`.
- **Schema + business logic**: viết tay bằng SQL/PL/SQL thuần trong [`db/`](db/) — APEXlang **không** sinh phần này.
  - [`db/ddl/`](db/ddl/) — DDL tạo bảng, theo thứ tự số (001, 002, ...).
  - [`db/plsql/`](db/plsql/) — package PL/SQL (business logic).
  - [`db/seed/`](db/seed/) — dữ liệu mẫu/demo.

## 2. Môi trường cần có

- Oracle DB 26ai (trong dự án này chạy qua Docker container `apex-db`, cổng `1521`, service `FREEPDB1`) + ORDS/APEX (container `apex-ords`, cổng `8181`).
- SQLcl (`sql`) đã cài, có trong `PATH`.
- Node.js (cho `apexctl.mjs`).
- Một kết nối SQLcl đã lưu sẵn trỏ tới schema `ADMIN` của DB trên, dùng cho mọi lệnh `apexctl.mjs runtime ...`. Trong môi trường dev hiện tại, kết nối này đã được lưu sẵn với tên `admin_freepdb1` (xem `CLAUDE.md` — không có gì cần làm lại). Nếu thiết lập môi trường mới, tạo kết nối bằng:
  ```
  sql /nolog
  SQL> connect -save admin_freepdb1 -savepwd <user>/<password>@<host>:<port>/<service>
  ```

## 3. Cài đặt từ đầu (môi trường mới hoàn toàn)

Nếu DB đã có sẵn dữ liệu (như môi trường dev hiện tại), **bỏ qua bước 3.1–3.3** và chuyển thẳng sang mục 4 (chỉ áp dụng khi có thay đổi mới).

### 3.1. Tạo bảng (DDL)

Chạy lần lượt theo đúng thứ tự số (thứ tự này đã tôn trọng phụ thuộc khóa ngoại giữa các bảng):

```bash
cd /home/tuan/Documents/26house
for f in db/ddl/*.sql; do
  echo "=== $f ==="
  sql -S "ADMIN/<password>@localhost:1521/FREEPDB1" @"$f"
done
```

Danh sách file theo đúng thứ tự chạy:

| # | File | Nội dung |
| --- | --- | --- |
| 1 | `001_fr01_inventory_master.sql` | `SUPPLIER`, `WAREHOUSE`, `LOCATION`, `ITEM`, `LOT`, `INVENTORY_BALANCE`, view `V_INVENTORY_CURRENT` |
| 2 | `002_fr01_inventory_transaction.sql` | `INVENTORY_TRANSACTION` (sổ cái giao dịch tồn kho) |
| 3 | `003_fr02_inbound.sql` | `INBOUND_RECEIPT`, `INBOUND_RECEIPT_LINE` |
| 4 | `004_fr03_customer.sql` | `CUSTOMER` |
| 5 | `005_fr03_outbound.sql` | `OUTBOUND_ORDER`, `OUTBOUND_ORDER_LINE`, `PICK_WAVE`, `PICK_TASK`, `SHIP_PACKAGE`, `SHIP_PACKAGE_LINE`, `SHIPMENT` |
| 6 | `006_fr10_kpi_baseline.sql` | `KPI_BASELINE` |
| 7 | `007_fr07_quality.sql` | `QUALITY_INSPECTION`, `QUALITY_HOLD` |
| 8 | `008_fr09_integration.sql` | `INTEGRATION_ENDPOINT_CONFIG`, `INTEGRATION_LOG` |
| 9 | `009_fr01_uom.sql` | `UOM` (đơn vị tính, `ITEM.uom` tham chiếu qua FK), seed 5 dòng mặc định (EA/BOX/SET/PCS/PAIR) |

### 3.2. Deploy package PL/SQL

Package sau gọi package trước (`PKG_INVENTORY` là nền tảng, `PKG_OUTBOUND`/`PKG_QUALITY`/`PKG_INTEGRATION_IN` gọi các package khác) — **phải chạy đúng thứ tự dưới đây**:

```bash
for f in pkg_item pkg_location pkg_lot pkg_inventory pkg_inbound pkg_outbound pkg_picking pkg_packing pkg_shipment pkg_quality pkg_integration_out pkg_integration_in; do
  echo "=== $f ==="
  sql -S "ADMIN/<password>@localhost:1521/FREEPDB1" @db/plsql/$f.sql
done

# kiểm tra không còn lỗi compile
echo "select name, type, line, text from user_errors order by name, type, sequence;" \
  | sql -S "ADMIN/<password>@localhost:1521/FREEPDB1"
```

### 3.3. Import trang APEX (.apx)

**Đây là bước "import dữ liệu" thường bị nhầm với 3.4 — bước này import CẤU TRÚC TRANG (page/region/component), không phải dữ liệu bảng.**

Vì repo này để chung toolkit `apexlang/` (có 1 app mẫu lồng bên trong ở `apexlang/templates/base-app-structure/scaffold-example/`) ngay trong app thật, công cụ `apexctl.mjs` đôi khi quét nhầm sang app mẫu đó. Luôn import từ một **bản sao sạch** chỉ chứa đúng cấu trúc app thật:

```bash
CLEAN=/tmp/26house-clean-app   # hoặc thư mục scratchpad của phiên làm việc
rm -rf "$CLEAN" && mkdir -p "$CLEAN"
cp application.apx page-groups.apx "$CLEAN/"
cp -r pages shared-components deployments .apex "$CLEAN/"

cd apexlang
# 1. Validate cục bộ (nhanh, bắt lỗi cú pháp cơ bản)
node tools/apexctl.mjs apexlang validate --app-path "$CLEAN"

# 2. Validate + import thật vào DB (bắt buộc có --workspaceid, xem CLAUDE.md)
node tools/apexctl.mjs runtime roundtrip \
  --app-path "$CLEAN" \
  --db-connection-name admin_freepdb1 \
  --import-intent validate-and-import \
  --target-resolution-mode update-existing \
  --skip-runtime-verification \
  --execution-mode path \
  --workspaceid 6802490454262707
```

App càng nhiều trang thì bước 2 càng lâu — dùng `timeout 480` (hoặc hơn) khi gọi qua script, tránh timeout giữa chừng.

## 4. Import dữ liệu (seed / demo data)

Đây mới đúng là "import dữ liệu" theo nghĩa nạp bản ghi vào bảng. Chạy theo thứ tự (mỗi file phụ thuộc dữ liệu của file trước):

```bash
for f in db/seed/*.sql; do
  echo "=== $f ==="
  sql -S "ADMIN/<password>@localhost:1521/FREEPDB1" @"$f"
done
```

| # | File | Nội dung | Ghi chú |
| --- | --- | --- | --- |
| 1 | `001_fr01_sample_data.sql` | 1 supplier, 1 warehouse, 3 location, 5 item, 2 lot, 3 dòng tồn kho | Chạy sau `db/ddl/001` và `002` |
| 2 | `002_fr03_outbound_sample_data.sql` | 1 location SHIPPING, 2 customer, 2 đơn hàng demo (1 đơn chạy hết vòng đời đến SHIPPED, 1 đơn dừng ở ALLOCATED) — dùng chính `PKG_OUTBOUND`/`PKG_PICKING`/`PKG_PACKING`/`PKG_SHIPMENT` để tạo, không insert thẳng | Chạy sau khi đã deploy xong toàn bộ package ở mục 3.2 |
| 3 | `003_fr10_kpi_baseline_placeholder.sql` | 3 dòng KPI baseline **GIẢ ĐỊNH** (`is_placeholder='Y'`) | ⚠️ Chỉ dùng cho dev/demo — **phải thay bằng số liệu đo thật trước khi UAT/nộp báo cáo SIEA**, xem `TASKS.md` mục FR-10 |

### Import dữ liệu thật (khác với seed demo)

Nếu cần nạp dữ liệu thật từ hệ thống cũ (không phải demo):
- **Chưa có script tự động** — đây là Phase 7 (Migration) trong `PROJECT-PLAN.md`/`TASKS.md`, hiện chưa triển khai.
- Khi làm, nên viết script migration riêng trong `db/seed/` hoặc một thư mục `db/migration/` mới, đối chiếu số dòng/số lượng giữa dữ liệu cũ và dữ liệu đã nạp (row count, tổng số lượng, spot-check theo item) trước khi coi là hoàn tất — xem checklist Phase 7 trong `PROJECT-PLAN.md`.
- Với dữ liệu nghiệp vụ đi qua state machine (đơn hàng, phiếu nhập kho...), **luôn nạp qua package PL/SQL tương ứng** (`PKG_INBOUND`, `PKG_OUTBOUND`, ...), không insert thẳng vào bảng — xem ví dụ cách làm trong `db/seed/002_fr03_outbound_sample_data.sql`.

## 5. Truy cập ứng dụng

- URL: `http://localhost:8181/ords/r/tdt203/26house/` (hoặc rút gọn `http://localhost:8181/ords/f?p=105:1`).
- Đăng nhập bằng tài khoản APEX workspace `tdt203`.
- Trang chủ (Home) liệt kê menu điều hướng tới các trang chức năng chính (Items, Locations, Lots, UOM, Warehouses, Suppliers, Inventory Balance/Transactions, Inbound Receipts, Outbound Orders, Pick Tasks, Shipments, Quality Inspections/Holds, Operations Dashboard, Integration Monitor, KPI Baseline...). Menu điều hướng (sidebar) được gom theo nhóm cha-con (Master Data, Inventory, Outbound, Quality, Reporting, Integration). Trang Inbound Receipts nằm trong nhóm Inventory, gộp cả header và dòng (Master-Detail) trên cùng 1 trang.
- Mọi trang danh mục/chứng từ đều là 1 Interactive Grid duy nhất (thêm/sửa/xóa trực tiếp trong lưới). Cột tham chiếu (many2one, vd `Items.uom`, `Locations.warehouse_id`, `Outbound Orders.customer_id`...) là dropdown thật lấy từ LOV dùng chung khai báo ở `shared-components/lovs.apx`, chỉ hiện bản ghi đang active; cột boolean (vd `Active`, `Lot Tracked`) là checkbox thật ngay trong lưới.

## 6. Kiểm tra nhanh sau khi cài đặt

```sql
-- Đếm nhanh vài bảng chính để xác nhận DDL + seed đã chạy đủ
select 'ITEM' t, count(*) c from item
union all select 'LOCATION', count(*) from location
union all select 'OUTBOUND_ORDER', count(*) from outbound_order
union all select 'KPI_BASELINE', count(*) from kpi_baseline;
```

```bash
# Xác nhận đủ trang trong app APEX
echo "select page_id, page_name from apex_application_pages where application_id=105 order by page_id;" \
  | sql -S "ADMIN/<password>@localhost:1521/FREEPDB1"
```

## 7. Deploy tự động (CI/CD)

Server remote (`wms_remote`, app id 100, workspace `26HOUSE`) được **tự động deploy khi merge vào branch `main`** qua GitHub Actions (`.github/workflows/deploy-wms-remote.yml`): chạy các file `db/ddl/` mới thêm/đổi trong lần merge đó (không rerun file cũ vì `create table` không idempotent), toàn bộ package trong `db/plsql/` (idempotent, luôn rerun hết), rồi build bản sao sạch và import trang `.apx` vào app 100 — đúng quy trình thủ công ở mục 3.1–3.3 và `.claude/skills/deploy/SKILL.md`. `db/seed/` (dữ liệu demo) **không** nằm trong pipeline tự động, tiếp tục chạy tay khi cần.

Cần cấu hình 1 secret trong repo GitHub trước khi pipeline chạy được: `WMS_DB_CONNECT_STRING` (Settings → Secrets and variables → Actions), dạng `26HOUSE/<password>@18.181.77.39:1521/FREEPDB1` — xem chi tiết trong file workflow. Deploy lên local dev (mục 3.1–3.3, kết nối `admin_freepdb1`) vẫn phải chạy tay như trước, vì đó là DB chạy trong Docker chỉ máy dev mới truy cập được.

Pipeline chạy trên **self-hosted runner** (Docker), không dùng runner tính phí của GitHub — xem `.github/self-hosted-runner/README.md` để đăng ký runner. Nếu chưa đăng ký runner nào, job trên GitHub Actions sẽ đứng chờ (queued) mãi, không có gì nhận job.

## 8. Tài liệu liên quan

- [`26house-new-system.docx`](26house-new-system.docx) — yêu cầu nghiệp vụ gốc.
- [`PROJECT-PLAN.md`](PROJECT-PLAN.md) — kế hoạch tổng, mô hình dữ liệu, mapping module, rào chắn tuân thủ.
- [`TASKS.md`](TASKS.md) — trạng thái triển khai theo từng yêu cầu (FR-01..FR-10), việc cần làm tiếp.
- [`CLAUDE.md`](CLAUDE.md) — quy ước ngôn ngữ file, thông tin kỹ thuật DB/APEX, các lỗi/gotcha đã gặp và cách sửa.
