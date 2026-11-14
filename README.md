# Etsgo

Ứng dụng iOS giúp học sinh/sinh viên biến mong muốn học thành các bước, xếp lịch theo context cá nhân và thực hiện bằng Pomodoro.

- [Đặc tả và thiết kế kỹ thuật](MVP_SPEC.md): quyết định tại mục 12, dữ liệu/API tại mục 13–14, phân công và nghiệm thu tại mục 15–16.
- [Business Model Canvas](BUSINESS_MODEL_CANVAS.md).

## Chạy trên MacBook và iOS Simulator

Cần **Xcode 16+**, iOS Simulator 17+, **Docker Desktop đang chạy** và Git. Teammate chạy backend trên chính MacBook; `localhost` trong Simulator trỏ tới Mac, không phải máy Windows của thành viên khác.

### 1. Lấy đúng nhánh

```sh
git clone https://github.com/manhleduy2007-dotcom/Etsgo.git
cd Etsgo
git switch feature/backend-integration
```

Nếu đã clone, dùng `git fetch origin`, chuyển sang nhánh trên và `git pull --ff-only` sau khi xử lý thay đổi local của mình.

### 2. Cấu hình local, chưa cần dịch vụ ngoài

Tại thư mục chứa `compose.yaml`:

```sh
cp .env.example .env
python3 - <<'PY'
from pathlib import Path
import secrets
p = Path('.env')
s = p.read_text()
s = s.replace('ENVIRONMENT=production', 'ENVIRONMENT=development')
s = s.replace('DEV_AUTH_SECRET=\n', 'DEV_AUTH_SECRET=' + secrets.token_urlsafe(48) + '\n')
p.write_text(s)
PY
docker compose up --build
```

Chỉ sao chép cho lần setup đầu; không ghi đè `.env` đã chứa cấu hình riêng. Không commit `.env` hoặc gửi khóa vào chat.

Compose khởi động PostgreSQL → migration → API và worker. API publish tại **127.0.0.1:8000**. Lần build đầu cần mạng để tải image/dependency. Mở `http://localhost:8000/health` để xem server sẵn sàng; OpenAPI ở `http://localhost:8000/docs`.

### 3. Mở app

```sh
open TodoList.xcodeproj
```

1. Chọn scheme **TodoList**, một iPhone Simulator và Run.
2. Ở màn hình đăng nhập, giữ URL **http://localhost:8000**.
3. Trong bản **DEBUG**, chọn **Sign in to localhost (development server only)**.
4. Bỏ qua onboarding hoặc chọn Việt/Anh, bổ sung context và lịch học tuần.
5. Có thể tạo việc thủ công, đồng bộ, đề xuất lịch bằng thuật toán và chạy Pomodoro.

Development login chỉ hoạt động khi backend ở `development`, có secret đủ dài và kết nối local. Compose cho phép gateway nội bộ Docker vì port chỉ publish lên loopback. Không dùng cấu hình local làm môi trường công khai. Release không có nút đăng nhập development.

Với iPhone thật, cần backend HTTPS truy cập được từ điện thoại và tài khoản đăng nhập thật. `localhost` trên iPhone thật là chính iPhone; development login không phải phương thức đăng nhập thiết bị thật.

## Chưa có dịch vụ ngoài thì dùng được gì?

| Chức năng | Local chưa có credentials |
|---|---|
| Đăng nhập development trên simulator | Có, theo hướng dẫn trên. |
| Công việc, việc con, nhắc việc, việc lặp | Có. Bản lặp chính tiếp theo được tạo khi server nhận hoàn thành. |
| Context người dùng tự nhập | Có, đồng bộ lên backend. |
| Lịch tuần, commitment, đề xuất/duyệt lịch | Có; app báo thiếu dữ liệu nếu chưa nối lịch ngoài. |
| Pomodoro và kết quả | Có; dùng local/offline sau khi đăng nhập. |
| Hội thoại AI, chia việc, handoff AI, guidance/unblock | Cần khóa/model AI. Thiếu cấu hình báo lỗi rõ, không tạo kết quả giả. |
| Đăng nhập bằng OpenAI key | Nhập key hợp lệ; backend kiểm tra quyền dùng model và cấp phiên Etsgo. Không gửi email. |
| Google Calendar | Cần OAuth client và Calendar API. |
| EventKit | Cần quyền và dữ liệu Calendar trên simulator/thiết bị. Không cần Google OAuth nếu chỉ đọc EventKit. |
| Thanh toán | Chưa thuộc mốc đầu. |

Không có credentials không ngăn app mở và dùng to-do, đồng bộ local cùng bộ lập lịch; không có nghĩa luồng AI/Google thật đã được nghiệm thu.

## Cấu hình dịch vụ thật

### Đăng nhập bằng OpenAI API key

- App chỉ yêu cầu OpenAI key, không có email/gửi mã OTP. Trong `/docs`, dùng `POST /v1/auth/api-key` với JSON `{"api_key":"key_mới"}`, rồi dùng `access_token` trả về cho Authorize. Không nhập key trực tiếp vào Authorize.
- Backend kiểm tra key bằng thao tác đọc model OpenAI, không tạo nội dung ở bước đăng nhập. Quyền truy cập model không chứng minh tài khoản còn đủ quota/credit để sinh nội dung.
- Cấu hình `AI_PROVIDER=openai`, `AI_MODEL` là model được cấp quyền. Tạo `APP_SESSION_SECRET` bằng `openssl rand -hex 32` và `ENCRYPTION_KEY` theo `.env.example`. Trong development, có thể dùng `DEV_AUTH_SECRET` làm secret phiên nếu chưa đặt `APP_SESSION_SECRET`.
- Nếu Mac chưa có thư viện cryptography, sau `docker compose build api` có thể tạo encryption key bằng `docker compose run --rm --no-deps api python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`, rồi điền vào `.env` và recreate API/worker.
- Key được mã hóa trong PostgreSQL, không trả về app hoặc đưa vào job/context/log. Worker lấy key đúng owner, không dùng key người khác. App chỉ giữ token phiên trong Keychain.
- Cùng key trên cùng backend dùng chung dữ liệu demo. Đổi key tạo danh tính khác, không tự chuyển dữ liệu. Đây là cơ chế demo dùng key làm danh tính, không phải mô hình tài khoản freemium cuối cùng.
- Giữ `ENCRYPTION_KEY` ổn định: nó bảo vệ khóa đã lưu và định danh dữ liệu demo. Thay secret ký phiên làm token cũ hết hiệu lực; người dùng nhập lại key.
- Khi chạy backend từ xa, dùng HTTPS. Database có thể là PostgreSQL local hoặc Supabase PostgreSQL; không cần Supabase Auth/SMTP. FastAPI vẫn kiểm tra token và owner; không mở truy cập trực tiếp bảng cho app.

### AI

OpenAI adapter đã được kiểm tra bằng SDK thật với HTTP giả cho kết quả hợp lệ, refusal/incomplete và lỗi xác thực/request. Bộ backend hiện có 24 ca qua local; chưa gọi OpenAI thật bằng khóa người dùng. Phải đặt khóa mới trong `.env` rồi khởi động lại API/worker để kích hoạt.

- OpenAI: đặt `AI_PROVIDER=openai`, `OPENAI_API_KEY` và `AI_MODEL=gpt-4.1-mini` (hoặc model hỗ trợ Structured Outputs được cấp quyền trên tài khoản). Backend dùng Responses API với schema Pydantic, không cần sửa app iOS.
- Anthropic vẫn được hỗ trợ: đặt `AI_PROVIDER=anthropic`, `ANTHROPIC_API_KEY` và model tương ứng trong `AI_MODEL`. Không có fallback tự gửi context sang provider khác.
- Chỉ lưu khóa trong `.env` của backend/secret môi trường triển khai; không đưa vào Swift, `.env.example`, Git hay chat. Nếu khóa đã bị lộ, thu hồi và thay khóa mới trước khi sử dụng.
- Sau khi đổi cấu hình: khởi động lại **cả API lẫn worker**. Với Docker dùng `docker compose up --build -d --force-recreate api worker`.
- Khóa nằm ở backend. Model là cấu hình, không hardcode trong iOS.
- Chưa cấu hình thì job báo `ai_not_configured`; quota user được hoàn khi job kết thúc lỗi. Quota sản phẩm không đồng nghĩa chi phí provider.

### Google Calendar / EventKit

- Tạo OAuth **Web client**, bật Calendar API, đặt redirect đúng `${PUBLIC_URL}/v1/calendar/google/callback`. Thêm tài khoản thử vào consent screen nếu đang testing.
- Điền `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `PUBLIC_URL`; tạo `ENCRYPTION_KEY` theo `.env.example`. Giữ encryption key ổn định sau khi lưu refresh token.
- Trong app: Cài đặt → Tài khoản và đồng bộ → Kết nối Google Calendar. Sau khi kết nối, dùng **Chọn lịch Google cần đọc**, chọn các nguồn rồi lưu. Mặc định đọc primary; có thể chọn nhiều lịch. Lịch Etsgo dùng để ghi bị loại khỏi danh sách nguồn busy.
- Bật kết nối lịch iPhone để đọc EventKit. Khi dùng Google trực tiếp đồng thời, chọn nguồn EventKit và bỏ lịch Google trùng. Lịch Etsgo không tính là busy bên ngoài.
- Duyệt lịch trong app chưa ghi Calendar. Phải xác nhận xuất riêng; một phiên chỉ có một đích. Xuất lại cùng đích bao gồm dọn các phiên Etsgo cũ không còn dùng.
- Khi mất quyền hoặc dữ liệu ngoài bị sửa, cần kết nối/đối chiếu lại; gửi request không đồng nghĩa đã ghi thành công.

## Cấu trúc

```text
backend/
  app/config.py, auth.py           Cấu hình, đăng nhập key và token phiên
  app/db.py, schemas.py            Store và kiểm tra dữ liệu
  app/sync.py                     Version, receipt, tombstone, CRUD
  app/ai.py, worker.py             AI/context và job/quota bền vững
  app/scheduler.py                Lập lịch và kiểm tra đề xuất
  app/calendar.py                 OAuth, Google busy và xuất lịch
  app/main.py                     API /v1, OpenAPI, proposal/accept
  migrations/                     Alembic migrations
  tests/                          Các kiểm tra PostgreSQL đã có
TodoList/
  Models/SyncState.swift           SyncRecord, outbox, PlannedSession
  Services/BackendClient.swift    Auth session, API và job polling
  Services/SyncCoordinator.swift  Local outbox, push/pull, conflict
  Services/CalendarService.swift  EventKit snapshot và lệnh đã duyệt
  Views/                          SwiftUI và Pomodoro local
```

SwiftData là bản local; server giữ dữ liệu chính. AI tạo proposal, backend kiểm tra và áp dụng sau duyệt. Worker và quota dùng PostgreSQL chung, không cần Redis. Context được lưu có nguồn/phạm vi, bản tóm tắt cho AI là dữ liệu dẫn xuất.

Conflict xử lý ở Cài đặt → Tài khoản và đồng bộ. Đăng xuất kiểm tra thay đổi chưa đồng bộ trước khi xóa cache; không chuyển dữ liệu tài khoản cũ sang tài khoản mới.

## Chạy Python trực tiếp

Cần PostgreSQL, Python 3.12 và `.env` ở gốc repository. Trong `backend/`:

```sh
python3 -m venv ../.venv
source ../.venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-access-log
```

Terminal khác, activate cùng virtualenv, vào `backend/`, chạy `python -m app.worker`. `DATABASE_URL` phải trỏ tới PostgreSQL đang chạy. Có thể chỉ chạy database bằng `docker compose up db` và dùng connection string local trong `.env.example`.

## Trạng thái bàn giao

- Bản mã `f94c59e` đã qua [CI backend và build iOS Simulator trên macOS](https://github.com/manhleduy2007-dotcom/Etsgo/actions/runs/43573712873). Bộ backend hiện có 18 ca kiểm tra, qua trên PostgreSQL thật. Build thành công chưa thay thế việc chạy tương tác và nghiệm thu dịch vụ thật trên Mac/iPhone.

- Trước yêu cầu tạm bỏ qua kiểm thử: đã chạy 13 ca backend trên PostgreSQL thật ở Windows. CI của commit `facdc93` có backend và build iOS Simulator trên macOS thành công.
- Sau khi tiếp tục công việc: 18 ca backend qua trên PostgreSQL thật, gồm chọn lịch Google, phân trang, lỗi EventKit, xung đột tạo sự kiện và luồng duyệt → xuất → xếp lại → từ chối phản hồi cũ. Đây là kiểm thử với HTTP giả có kiểm soát; chưa thay thế nghiệm thu tài khoản Google thật. Xem CI/Git history cho trạng thái build iOS của từng commit.
- Chưa chạy app tương tác trên simulator/iPhone; chưa nghiệm thu AI hoặc Google thật vì chưa có dịch vụ/credentials. Chất lượng AI Việt/Anh, backup/restore và các tình huống đầy đủ cần làm trước phát hành.
- Workflow `.github/workflows/ci.yml` có kiểm tra PostgreSQL và build Xcode để nhóm dùng khi tiếp tục. Chưa chạy không có nghĩa đã đạt.
- `.env`, `.venv`, `.tools` không thuộc nguồn bàn giao. PostgreSQL portable đang dùng trên Windows nằm trong `.tools`; teammate Mac dùng Docker hoặc PostgreSQL của Mac.
- Giá trị chưa chốt: model AI cuối, hạn mức thương mại, chính sách dữ liệu người chưa thành niên và hosting thật. App đã có chọn lịch Google và làm mới trạng thái xuất lịch; kiểm thử tương tác thiết bị vẫn cần thực hiện trên Mac.

## Lệnh khi nhóm tiếp tục kiểm thử

Tạo PostgreSQL riêng tên `etsgo_test`, đặt `DATABASE_URL` trỏ tới đó, chạy trong `backend/`:

```sh
alembic upgrade head
pytest -q
ruff check .
```

Không trỏ test vào database người dùng. Fake provider trong test chỉ kiểm tra job/error flow, không chứng minh tích hợp AI thật.

Build simulator trên Mac:

```sh
xcodebuild -project TodoList.xcodeproj -scheme TodoList -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

`docker compose down` dừng môi trường, giữ volume. Không dùng `down -v` nếu muốn giữ dữ liệu. Backup bằng `pg_dump`, restore vào database riêng bằng `pg_restore`, rồi xác nhận dữ liệu trước khi coi backup dùng được.
