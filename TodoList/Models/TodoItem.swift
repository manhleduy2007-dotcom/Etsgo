import Foundation
import SwiftData

enum Priority: Int, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: return "Thấp"
        case .medium: return "Trung bình"
        case .high: return "Cao"
        }
    }

    /// Tên dùng khi trao đổi với AI.
    var apiName: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }

    init?(apiName: String) {
        guard let match = Priority.allCases.first(where: { $0.apiName == apiName }) else { return nil }
        self = match
    }
}

@Model
final class TodoItem {
    var title: String = ""
    var notes: String = ""
    var isDone: Bool = false
    var createdAt: Date = Date.now
    var dueDate: Date?
    var priorityRaw: Int = 1
    /// Thời lượng ước tính, tính bằng phút.
    var estimatedMinutes: Int = 30
    /// Giờ bắt đầu do bộ xếp lịch gán.
    var scheduledStart: Date?
    /// Mã sự kiện tương ứng trong ứng dụng Lịch (nếu đã đồng bộ).
    var calendarEventID: String?
    /// Lý do AI đưa ra khi đề xuất mức ưu tiên.
    var aiReason: String = ""
    /// Thứ tự trong danh sách bước nhỏ của công việc cha.
    var order: Int = 0

    var parent: TodoItem?
    @Relationship(deleteRule: .cascade, inverse: \TodoItem.parent)
    var subtasks: [TodoItem] = []

    init(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        priority: Priority = .medium,
        estimatedMinutes: Int = 30
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
        self.estimatedMinutes = estimatedMinutes
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return dueDate < .now
    }

    var scheduledEnd: Date? {
        scheduledStart?.addingTimeInterval(TimeInterval(max(estimatedMinutes, 15) * 60))
    }

    var sortedSubtasks: [TodoItem] {
        subtasks.sorted { $0.order < $1.order }
    }

    /// Bước nhỏ thừa hưởng mức ưu tiên và hạn chót của công việc cha.
    var effectivePriorityRaw: Int {
        max(priorityRaw, parent?.priorityRaw ?? 0)
    }

    var effectiveDueDate: Date? {
        dueDate ?? parent?.dueDate
    }

    func addSubtask(title: String, estimatedMinutes: Int = 30) {
        let sub = TodoItem(title: title, estimatedMinutes: estimatedMinutes)
        sub.order = (subtasks.map(\.order).max() ?? -1) + 1
        sub.parent = self
        subtasks.append(sub)
    }
}

extension ModelContext {
    /// Xoá công việc cùng các sự kiện Lịch đã tạo cho nó và các bước nhỏ.
    @MainActor
    func deleteTodo(_ item: TodoItem) {
        for task in [item] + item.subtasks {
            if let id = task.calendarEventID {
                CalendarService.shared.removeEvent(id: id)
            }
        }
        delete(item)
    }
}
