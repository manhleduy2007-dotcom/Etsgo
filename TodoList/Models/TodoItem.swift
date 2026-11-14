import Foundation
import SwiftData
import SwiftUI

enum Priority: Int, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: return L("Thấp", "Low")
        case .medium: return L("Trung bình", "Medium")
        case .high: return L("Cao", "High")
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

/// Danh sách / nhóm của công việc. AI chọn nhóm khi người dùng nhập bằng lời.
enum TaskCategory: String, CaseIterable, Identifiable {
    case study, work, personal, health, finance, home, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: return L("Học tập", "Study")
        case .work: return L("Công việc", "Work")
        case .personal: return L("Cá nhân", "Personal")
        case .health: return L("Sức khoẻ", "Health")
        case .finance: return L("Tài chính", "Finance")
        case .home: return L("Nhà cửa", "Home")
        case .other: return L("Khác", "Other")
        }
    }

    var color: Color {
        switch self {
        case .work: return Color(light: 0x2747E5, dark: 0x8FA4FF)
        case .study: return Color(light: 0x7A45D6, dark: 0xBD9BFF)
        case .personal: return Color(light: 0xD43F6C, dark: 0xFF8FB0)
        case .health: return Color(light: 0x12875F, dark: 0x5ED6AA)
        case .finance: return Color(light: 0xA66A12, dark: 0xF0B85A)
        case .home: return Color(light: 0x0B7F97, dark: 0x62CFE6)
        case .other: return Color(light: 0x5F6779, dark: 0xA7AEC2)
        }
    }
}

enum RepeatRule: String, CaseIterable, Identifiable {
    case none, daily, weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L("Không lặp", "Never")
        case .daily: return L("Hằng ngày", "Daily")
        case .weekly: return L("Hằng tuần", "Weekly")
        }
    }

    func next(after date: Date) -> Date? {
        switch self {
        case .none: return nil
        case .daily: return Calendar.current.date(byAdding: .day, value: 1, to: date)
        case .weekly: return Calendar.current.date(byAdding: .day, value: 7, to: date)
        }
    }
}

@Model
final class TodoItem {
    var uid: String = UUID().uuidString.lowercased()
    var title: String = ""
    var notes: String = ""
    var isDone: Bool = false
    var createdAt: Date = Date.now
    var dueDate: Date?
    var priorityRaw: Int = 1
    var categoryRaw: String = "other"
    /// Thời lượng ước tính, tính bằng phút (tổng thời gian chiếm trên lịch).
    var estimatedMinutes: Int = 30
    /// Giờ bắt đầu đã được người dùng duyệt.
    var scheduledStart: Date?
    /// Mã sự kiện tương ứng trong ứng dụng Lịch (nếu đã ghi).
    var calendarEventID: String?
    /// Lý do AI đưa ra khi đề xuất mức ưu tiên.
    var aiReason: String = ""
    /// Thứ tự trong danh sách bước của công việc cha.
    var order: Int = 0

    var remind: Bool = false
    var repeatRaw: String = "none"

    /// Độ dài phiên tập trung / nghỉ đề xuất cho việc này, sửa được trước khi chạy.
    var focusMinutes: Int = 25
    var breakMinutes: Int = 5
    /// Tổng thời gian tập trung đã chạy cho việc này.
    var spentSeconds: Int = 0
    var isStuck: Bool = false

    /// Hướng dẫn ngắn và gợi ý tài liệu do AI đưa ra khi bắt đầu việc. Chưa kiểm chứng.
    var guidanceTip: String = ""
    var resourceTitle: String = ""
    var resourceQuery: String = ""

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

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRaw) ?? .none }
        set { repeatRaw = newValue.rawValue }
    }

    /// Bước nhỏ mang nhóm của công việc cha.
    var effectiveCategory: TaskCategory {
        parent?.category ?? category
    }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return dueDate < .now
    }

    var scheduledEnd: Date? {
        scheduledStart?.addingTimeInterval(TimeInterval(max(estimatedMinutes, 15) * 60))
    }

    /// Phiên đã duyệt nhưng đã trôi qua mà việc chưa xong.
    var isMissed: Bool {
        guard !isDone, let end = scheduledEnd else { return false }
        return end < .now
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

    @discardableResult
    func addSubtask(title: String, estimatedMinutes: Int = 30, focus: Int = 25, rest: Int = 5) -> TodoItem {
        let sub = TodoItem(title: title, estimatedMinutes: estimatedMinutes)
        sub.order = (subtasks.map(\.order).max() ?? -1) + 1
        sub.focusMinutes = focus
        sub.breakMinutes = rest
        sub.parent = self
        subtasks.append(sub)
        return sub
    }

    /// Chèn các bước mới ngay sau việc này (nếu là bước nhỏ) hoặc thành bước nhỏ của nó.
    func insertFollowUpSteps(_ steps: [(title: String, minutes: Int)]) {
        guard let parent else {
            for step in steps { addSubtask(title: step.title, estimatedMinutes: step.minutes) }
            return
        }
        for sibling in parent.subtasks where sibling.order > order {
            sibling.order += steps.count
        }
        for (index, step) in steps.enumerated() {
            let sub = TodoItem(title: step.title, estimatedMinutes: step.minutes)
            sub.order = order + 1 + index
            sub.parent = parent
            parent.subtasks.append(sub)
        }
    }
}

/// Một mẩu context cá nhân. Phân biệt điều người dùng xác nhận với thông tin nhập từ AI khác.
@Model
final class ContextItem {
    var uid: String = UUID().uuidString.lowercased()
    var scope: String = "personal"
    var scopeID: String?
    var validUntil: Date?
    var text: String = ""
    /// "user" (người dùng tự nhập), "handoff" (từ AI khác), "assumption" (AI suy đoán).
    var sourceRaw: String = "user"
    var confirmed: Bool = true
    var createdAt: Date = Date.now

    init(text: String, source: String, confirmed: Bool) {
        self.text = text
        self.sourceRaw = source
        self.confirmed = confirmed
    }

    var sourceLabel: String {
        if confirmed { return L("Bạn đã xác nhận", "Confirmed by you") }
        switch sourceRaw {
        case "handoff": return L("Từ AI khác, chưa xác nhận", "From another AI, unconfirmed")
        case "assumption": return L("AI suy đoán, chưa xác nhận", "AI's guess, unconfirmed")
        default: return L("Chưa xác nhận", "Unconfirmed")
        }
    }

    /// Nhãn gửi kèm cho AI để nó biết mức tin cậy của từng mẩu.
    var promptLine: String {
        let tag = confirmed ? "confirmed by the user"
            : (sourceRaw == "handoff" ? "imported from another AI, unconfirmed, may be outdated" : "a guess, unconfirmed")
        return "- [\(tag)] \(text)"
    }
}

/// Một phiên tập trung đã chạy. Thời gian chạy không đồng nghĩa việc đã xong.
@Model
final class FocusSession {
    var uid: String = UUID().uuidString.lowercased()
    var taskID: String?
    var finishedAt: Date?
    var taskTitle: String = ""
    var startedAt: Date = Date.now
    var focusSeconds: Int = 0
    /// "done", "more_time", "stuck", "break", "ended"
    var outcomeRaw: String = "ended"

    init(taskTitle: String, focusSeconds: Int) {
        self.taskTitle = taskTitle
        self.focusSeconds = focusSeconds
    }
}

extension ModelContext {
    /// Xoá công việc cùng lời nhắc và các sự kiện Lịch đã ghi cho nó và các bước nhỏ.
    @MainActor
    func deleteTodo(_ item: TodoItem) {
        for task in [item] + item.subtasks {
            NotificationService.cancel(task.uid)
            if let id = task.calendarEventID {
                CalendarService.shared.removeEvent(id: id)
            }
        }
        delete(item)
    }

    /// Đánh dấu xong / mở lại, xử lý việc lặp, lời nhắc và trạng thái của việc cha.
    @MainActor
    func setDone(_ item: TodoItem, _ done: Bool) {
        guard item.isDone != done else { return }
        item.isDone = done
        if done {
            item.isStuck = false
            NotificationService.cancel(item.uid)
            if !BackendClient.shared.signedIn, item.parent == nil, let nextDue = item.repeatRule.next(after: item.dueDate ?? .now) {
                let copy = TodoItem(
                    title: item.title,
                    notes: item.notes,
                    dueDate: nextDue,
                    priority: item.priority,
                    estimatedMinutes: item.estimatedMinutes
                )
                copy.category = item.category
                copy.repeatRule = item.repeatRule
                copy.remind = item.remind
                copy.focusMinutes = item.focusMinutes
                copy.breakMinutes = item.breakMinutes
                insert(copy)
                NotificationService.scheduleReminder(for: copy)
            }
        } else {
            NotificationService.scheduleReminder(for: item)
        }
        if let parent = item.parent {
            if parent.subtasks.allSatisfy(\.isDone) {
                setDone(parent, true)
            } else if !done {
                setDone(parent, false)
            }
        }
    }
}
