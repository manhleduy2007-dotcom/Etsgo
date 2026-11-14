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
}

@Model
final class TodoItem {
    var title: String
    var notes: String
    var isDone: Bool
    var createdAt: Date
    var dueDate: Date?
    var priorityRaw: Int

    init(
        title: String,
        notes: String = "",
        isDone: Bool = false,
        createdAt: Date = .now,
        dueDate: Date? = nil,
        priority: Priority = .medium
    ) {
        self.title = title
        self.notes = notes
        self.isDone = isDone
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return dueDate < .now
    }
}
