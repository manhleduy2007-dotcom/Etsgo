# Etsgo

Ứng dụng iOS (SwiftUI + SwiftData) giúp học sinh, sinh viên biến mong muốn học thành các bước làm được ngay, xếp vào lịch theo context cá nhân và thực hiện bằng Pomodoro. Đặc tả sản phẩm: [MVP_SPEC.md](MVP_SPEC.md). Mô hình kinh doanh: [BUSINESS_MODEL_CANVAS.md](BUSINESS_MODEL_CANVAS.md).

## Bắt đầu cho thành viên và agent

1. Đọc [bàn giao và trạng thái code](MVP_SPEC.md#11-bàn-giao-context-cho-các-agent-phát-triển), sau đó [quyết định kỹ thuật đã duyệt](MVP_SPEC.md#12-quyết-định-kỹ-thuật-đã-duyệt).
2. Đọc [baseline dữ liệu](MVP_SPEC.md#13-baseline-dữ-liệu-và-các-bất-biến) và [hợp đồng tích hợp](MVP_SPEC.md#14-hợp-đồng-tích-hợp-giữa-các-nhóm) trước khi thay model/API.
3. Nhận owner/phạm vi tại [phân công](MVP_SPEC.md#15-phân-công-để-nhiều-người-làm-song-song), thống nhất danh sách file trước khi thêm file. Theo [phase tích hợp và nghiệm thu](MVP_SPEC.md#16-thứ-tự-tích-hợp-và-điều-kiện-hoàn-thành).

Thiết kế đích đã duyệt: **Python/FastAPI + Supabase Auth/PostgreSQL; iOS lưu local và đồng bộ offline; context có cấu trúc; AI tạo proposal; scheduler server; EventKit + Google Calendar; quota server, chưa thanh toán**. Các phần này chưa được triển khai chỉ vì đã có tài liệu.

Baseline code được đọc là `aa9f237` trên nhánh `claude/dreamy-sagan-l66oau`. Quyết định mới thay thế lựa chọn tạm tương ứng trong code; kiểm tra branch/commit thực tế trước khi làm việc. Bản cập nhật tài liệu này không sửa mã ứng dụng, không bổ sung file hoặc dependency.

## Trạng thái

Mã nguồn đã viết theo đặc tả nhưng **chưa từng được biên dịch hay chạy** (môi trường viết mã không có Xcode), kể cả `TodoList.xcodeproj/project.pbxproj`. Chưa có unit test. Mọi mục "đã có" bên dưới nghĩa là đã có mã, chưa phải đã kiểm chứng.

## Yêu cầu trong đặc tả và mã tương ứng

| ID | Nội dung | Mã |
|---|---|---|
| TD-01 | Thêm, sửa, xoá, hoàn thành, mở lại; tạo việc không cần AI | `TodoListView`, `TodoEditorView` |
| TD-02 | Danh sách (nhóm), việc con, ngày giờ, ưu tiên, nhắc việc, việc lặp, tìm kiếm, lọc | `TodoItem`, `TodoEditorView`, `NotificationService` |
| AI-01 | Text và voice vào cùng luồng; sửa được nội dung nhận từ giọng nói | `SpeechRecognizer`, `MicButton` trong `Theme.swift` |
| AI-02, AI-03 | Hỏi từng câu ngắn có đáp án nhanh; nút "Cứ đề xuất trước" | `PlannerView`, `AIService.planTurn` |
| AI-04 | Phân rã, ước lượng; sửa/bỏ bước trực tiếp hoặc qua hội thoại | `PlannerView`, `AIService.breakdown` |
| CT-01 | Prompt handoff sao chép được; nhận nội dung và tổng hợp context | `HandoffImportView`, `AIService.summarizeHandoff` |
| CT-02 | Xem, sửa, xoá, xác nhận từng mẩu context | `ContextView`, `ContextItem` |
| CT-03 | Dùng context trong đề xuất; mục "Dựa trên" giải thích | `buildPromptContext`, `PlannerView` |
| CA-01 | Nhận lịch ngoài qua một phương thức | `CalendarService` (Lịch của iPhone, EventKit) |
| SC-01 | Lịch học tuần và xác nhận cam kết ngày | `StudySchedule`, `WeeklyScheduleEditor`, `ScheduleView` |
| SC-02 | Không chồng phiên, không vượt cam kết, giữ thứ tự bước | `Scheduler` |
| SC-03 | Nêu phần chưa xếp được và lý do; không tự tăng giờ | `ScheduleView` |
| SC-04 | Đề xuất → sửa → duyệt; ghi Lịch ngoài cần xác nhận riêng | `ScheduleView` |
| PO-01, PO-02 | Nhiều phiên cho một việc; độ dài tập trung/nghỉ sửa được; bắt đầu, tạm dừng, tiếp tục, kết thúc sớm | `PomodoroView` |
| PO-03 | Hết giờ không tự đánh dấu xong; cập nhật nhanh Xong / Cần thêm thời gian / Đang vướng | `PomodoroView` |
| EX-01, EX-02 | Hướng dẫn ngắn và một tài liệu khi bắt đầu việc, đổi được; không đưa URL, chỉ mở tìm kiếm và ghi rõ chưa kiểm chứng | `PomodoroView`, `AIService.guidance` |
| AD-01 | Sau khi lỡ, chưa xong hoặc vướng: đề xuất phương án, hiện thay đổi trước khi duyệt | `ScheduleView`, `AIService.unblock` |
| LG-01 | Việt / Anh cho giao diện và hội thoại | `AppLanguage`, hàm `L(_:_:)` |

## Lựa chọn trong code hiện tại và hướng chuyển đổi

Đây là trạng thái code tại baseline, không phải mô tả backend đã triển khai. Đối chiếu [mục 10](MVP_SPEC.md#10-trạng-thái-các-điểm-từng-để-mở) và [mục 12](MVP_SPEC.md#12-quyết-định-kỹ-thuật-đã-duyệt) để biết thiết kế mới đã duyệt:

- **Nền tảng:** iOS native, iOS 17+.
- **AI:** code gọi Claude (`claude-opus-5-5`) thẳng từ điện thoại bằng khoá người dùng tự nhập trong Keychain. Thiết kế mới chuyển khóa, gọi AI và hạn mức về backend; model/provider cuối chưa chốt.
- **Voice:** nhận dạng giọng nói của iOS (Speech framework).
- **Nguồn lịch:** code có EventKit. Thiết kế mới yêu cầu thêm Google Calendar ngay mốc đầu; Notion chưa thuộc đợt tích hợp này.
- **Cam kết:** tính cả giờ nghỉ, tức tổng thời gian chiếm trên lịch; đã được duyệt giữ nguyên.
- **Tài liệu học:** AI mô tả loại tài liệu và câu tìm kiếm; ứng dụng mở trang tìm kiếm web.
- **Việc lặp:** hằng ngày hoặc hằng tuần, tạo bản kế tiếp khi hoàn thành.

## Chưa làm

- Backend, tài khoản, đồng bộ offline với server và hạn mức miễn phí theo thiết kế đã duyệt. Thanh toán/gói trả phí nằm sau mốc thử nghiệm đầu.
- Chính sách lưu/xoá dữ liệu, đồng ý sử dụng dữ liệu, xử lý người dùng chưa thành niên.
- Đo lường (mục 9): mới chỉ lưu các phiên tập trung trong `FocusSession`, chưa có báo cáo.
- Bộ đếm Pomodoro khi app ở nền chỉ dựa vào mốc kết thúc và một thông báo; chưa có Live Activity.
- Kiểm thử chất lượng AI ở cả hai ngôn ngữ.

## Chạy

Cần Xcode 16 trở lên, iOS 17 trở lên.

1. Mở `TodoList.xcodeproj`, chọn một iPhone simulator, bấm Run (⌘R).
2. Ở phần thiết lập ban đầu: chọn ngôn ngữ, nhập khoá API Anthropic (tạo tại https://console.anthropic.com), tuỳ chọn nhập context và lịch học tuần. Mọi bước đều bỏ qua được.
3. Để chạy trên máy thật: target **TodoList → Signing & Capabilities**, chọn Team và đổi Bundle Identifier (`com.example.TodoList`).

## Cấu trúc

```
TodoList/
├── TodoListApp.swift              # Điểm vào, 4 tab, thiết lập ban đầu
├── Models/
│   ├── AppLanguage.swift          # Việt / Anh, hàm L(vi, en)
│   ├── TodoItem.swift             # Công việc, bước, ContextItem, FocusSession
│   └── StudySchedule.swift        # Lịch học tuần, cam kết theo ngày
├── Services/
│   ├── AIService.swift            # Các lời gọi Claude và prompt
│   ├── Scheduler.swift            # Đề xuất lịch theo cam kết và ràng buộc
│   ├── CalendarService.swift      # Lịch của iPhone (EventKit)
│   ├── NotificationService.swift  # Nhắc việc, báo hết phiên
│   ├── SpeechRecognizer.swift     # Giọng nói thành văn bản
│   └── KeychainStore.swift        # Lưu khoá API
└── Views/
    ├── Theme.swift                # Màu, kiểu chữ, thành phần dùng chung
    ├── TodoListView.swift         # Tab Công việc
    ├── TodoRowView.swift          # Thẻ công việc
    ├── TodoEditorView.swift       # Form thêm/sửa
    ├── PlannerView.swift          # Tab Kế hoạch: hội thoại lập kế hoạch học
    ├── ScheduleView.swift         # Tab Lịch: cam kết, đề xuất, duyệt
    ├── PomodoroView.swift         # Phiên tập trung
    ├── ContextView.swift          # Context cá nhân và handoff
    ├── SettingsView.swift         # Tab Cài đặt, lịch học tuần
    └── OnboardingView.swift       # Thiết lập ban đầu
```
