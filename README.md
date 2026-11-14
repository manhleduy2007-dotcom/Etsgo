# Etsgo – Việc cần làm

Ứng dụng to-do list native iOS, viết bằng SwiftUI + SwiftData.

## Tính năng

- Thêm nhanh ngay trên danh sách, hoặc bấm **+** để nhập đầy đủ (ghi chú, mức ưu tiên, hạn chót)
- Đánh dấu xong / chưa xong (bấm vòng tròn hoặc vuốt phải)
- Sửa (chạm vào dòng), xoá (vuốt trái), xoá toàn bộ việc đã xong
- Tìm kiếm, lọc theo trạng thái
- Việc chưa xong được xếp theo ưu tiên, rồi đến hạn chót; việc quá hạn hiện màu đỏ
- Dữ liệu lưu trên máy bằng SwiftData

## Chạy

Cần Xcode 16 trở lên, iOS 17 trở lên.

1. Mở `TodoList.xcodeproj`
2. Chọn một iPhone simulator rồi bấm Run (⌘R)

Để chạy trên máy thật, vào target **TodoList → Signing & Capabilities**, chọn Team và đổi Bundle Identifier (`com.example.TodoList`).

## Cấu trúc

```
TodoList/
├── TodoListApp.swift          # Điểm vào, khởi tạo SwiftData container
├── Models/TodoItem.swift      # Model + Priority
└── Views/
    ├── TodoListView.swift     # Màn hình danh sách
    ├── TodoRowView.swift      # Một dòng công việc
    └── TodoEditorView.swift   # Form thêm / sửa
```
