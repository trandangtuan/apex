# Self-hosted GitHub Actions runner cho pipeline deploy WMS

`deploy-wms-remote.yml` giờ chạy trên `runs-on: self-hosted` thay vì `ubuntu-latest` — nghĩa là **không tốn phút Actions tính phí của GitHub**, đổi lại bạn phải tự chạy 1 máy/container lắng nghe job. Thư mục này chứa `docker-compose.yml` để chạy runner đó bằng Docker (image cộng đồng `myoung34/github-runner`, bọc `actions-runner` chính chủ của GitHub).

## Yêu cầu

- Docker + Docker Compose đã cài trên máy sẽ chạy runner.
- Máy này cần **network tới được** cả GitHub (github.com, api.github.com) lẫn server DB remote (`18.181.77.39:1521`) — vì các bước deploy thật (SQLcl) chạy ngay trong container này.
- Không bắt buộc chạy trên cùng máy với `wms_remote`, nhưng nên chọn máy ổn định, luôn bật (runner offline thì merge vào `main` sẽ không có job nào nhận, không tự chạy bù sau).

## 1. Lấy registration token

Vào GitHub repo → **Settings → Actions → Runners → New self-hosted runner** → chọn OS **Linux**. GitHub hiện ra 1 token dạng `AXXXXXXXXXXXXXXXXXXXXXXXXXXXX` (chỉ hiển thị 1 lần, hết hạn sau ~1 giờ nếu chưa dùng).

## 2. Cấu hình

```bash
cd .github/self-hosted-runner
cp .env.example .env
# mở .env, dán token vừa lấy vào RUNNER_TOKEN=
```

## 3. Chạy runner

```bash
docker compose up -d
docker compose logs -f   # xác nhận thấy dòng "Listening for Jobs"
```

Runner sẽ hiện trong GitHub repo → Settings → Actions → Runners với tên `wms-deploy-runner`, trạng thái **Idle**. Từ giờ mỗi lần merge vào `main` (đổi `db/ddl`, `db/plsql`, `pages/`, `shared-components/`...), job sẽ tự chạy trên container này thay vì runner của GitHub.

## Lưu ý quan trọng

- **`RUNNER_TOKEN` chỉ dùng để đăng ký lần đầu** — sau khi container đăng ký thành công, thông tin runner được lưu trong volume `runner-config`, không cần token nữa cho tới khi bạn xóa volume này (`docker compose down -v`) hoặc GitHub tự hết hạn/thu hồi runner. Nếu phải đăng ký lại, lặp lại bước 1–2 với token mới.
- `EPHEMERAL: "false"` — runner chạy liên tục, nhận nhiều job tuần tự (không tự huỷ sau 1 job). Phù hợp cho 1 runner riêng của dự án này.
- Container này tự cài Node.js/Java/SQLcl mỗi lần chạy job (qua các step có sẵn trong `deploy-wms-remote.yml`) — không cần cài sẵn gì thêm trong image ngoài Docker.
- **Không commit file `.env` thật** (đã thêm vào `.gitignore`) — chỉ có `.env.example` (rỗng) được commit.
- Runner có quyền chạy code từ bất kỳ ai push được vào repo — chỉ cấp quyền push cho người bạn tin tưởng, và cân nhắc không bật self-hosted runner cho fork/PR từ bên ngoài (mặc định `RUNNER_SCOPE: repo` + workflow chỉ trigger trên `push` vào `main`/`workflow_dispatch`, không chạy trên `pull_request` từ fork, nên rủi ro này hiện không áp dụng).

## Dừng / gỡ runner

```bash
docker compose down        # dừng, giữ lại volume (đăng ký runner vẫn còn)
docker compose down -v     # dừng + xoá volume (phải đăng ký lại từ đầu nếu muốn dùng lại)
```

Sau đó GitHub repo → Settings → Actions → Runners → xoá runner đã offline nếu không dùng nữa.
