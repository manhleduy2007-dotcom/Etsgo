# Etsgo – Việc cần làm

Ứng dụng quản lý công việc native iOS (SwiftUI + SwiftData) có xếp lịch tự động, tích hợp Lịch của iPhone và AI.

## Tính năng

**Công việc**
- Thêm nhanh ngay trên danh sách, hoặc bấm **+** để nhập ghi chú, mức ưu tiên, thời lượng ước tính và hạn chót
- Đánh dấu xong, sửa, xoá, tìm kiếm, lọc theo trạng thái
- Mỗi công việc có thể có các bước nhỏ; xong hết các bước thì công việc cũng xong

**AI (Claude API)**
- **Chia nhỏ công việc**: mở một công việc → *AI chia nhỏ công việc* → nhận các bước cụ thể kèm thời lượng ước tính
- **Đề xuất ưu tiên**: nút ✨ trên danh sách → AI xem toàn bộ việc chưa xong, gán mức ưu tiên và ghi lý do cho từng việc

**Xếp lịch tự động** (tab *Lịch*)
- Xếp các việc chưa xong vào khoảng trống trong giờ làm việc của 14 ngày tới
- Việc ưu tiên cao và hạn gần được chọn chỗ trước; việc có bước nhỏ thì xếp theo từng bước
- Thuật toán chạy trên máy, không cần AI hay mạng

**Tích hợp Lịch** (EventKit)
- Đọc các sự kiện đã có để không xếp trùng giờ bận
- Ghi các khối công việc đã xếp vào ứng dụng Lịch; xếp lại hoặc xoá thì sự kiện được cập nhật theo

## Chạy

Cần Xcode 16 trở lên, iOS 17 trở lên.

1. Mở `TodoList.xcodeproj`
2. Chọn một iPhone simulator rồi bấm Run (⌘R)
3. Vào tab **Cài đặt**:
   - nhập khoá API Anthropic (tạo tại https://console.anthropic.com) để dùng tính năng AI
   - chỉnh giờ làm việc
   - bật **Đồng bộ với Lịch** và cấp quyền nếu muốn tích hợp Lịch

Để chạy trên máy thật, vào target **TodoList → Signing & Capabilities**, chọn Team và đổi Bundle Identifier (`com.example.TodoList`).

## Lưu ý về khoá API

Ứng dụng gọi thẳng Claude API từ điện thoại bằng khoá do người dùng tự nhập (lưu trong Keychain). Cách này phù hợp để dùng cá nhân và thử nghiệm. Nếu phát hành cho người khác, cần một backend đứng giữa giữ khoá, không nhúng khoá vào ứng dụng.

## Cấu trúc

```
TodoList/
├── TodoListApp.swift            # Điểm vào, 3 tab: Công việc / Lịch / Cài đặt
├── Models/TodoItem.swift        # Model công việc, bước nhỏ, mức ưu tiên
├── Services/
│   ├── AIService.swift          # Gọi Claude API: chia nhỏ, đề xuất ưu tiên
│   ├── Scheduler.swift          # Thuật toán xếp lịch
│   ├── CalendarService.swift    # Đọc/ghi Lịch qua EventKit
│   └── KeychainStore.swift      # Lưu khoá API
└── Views/
    ├── TodoListView.swift       # Danh sách công việc
    ├── TodoRowView.swift        # Một dòng công việc
    ├── TodoEditorView.swift     # Form thêm/sửa, các bước nhỏ
    ├── ScheduleView.swift       # Lịch đã xếp
    └── SettingsView.swift       # Khoá API, giờ làm việc, đồng bộ Lịch
```
