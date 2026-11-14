import EventKit
import Foundation

/// Đọc lịch bận và ghi các khối công việc vào ứng dụng Lịch của iPhone.
@MainActor
final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async -> Bool {
        if hasAccess { return true }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Các khoảng thời gian đã có sự kiện, bỏ qua sự kiện cả ngày và sự kiện do ứng dụng này tạo.
    func busyIntervals(from start: Date, to end: Date, excluding ownEventIDs: Set<String>) -> [DateInterval] {
        guard hasAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && !ownEventIDs.contains($0.eventIdentifier ?? "") }
            .filter { $0.endDate > $0.startDate }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
    }

    /// Tạo, cập nhật hoặc xoá sự kiện Lịch cho khớp với giờ đã xếp của công việc.
    func sync(_ item: TodoItem) {
        guard hasAccess else { return }
        guard !item.isDone, let start = item.scheduledStart, let end = item.scheduledEnd else {
            if let id = item.calendarEventID {
                removeEvent(id: id)
                item.calendarEventID = nil
            }
            return
        }

        let existing = item.calendarEventID.flatMap { store.event(withIdentifier: $0) }
        let event = existing ?? EKEvent(eventStore: store)
        if existing == nil {
            guard let calendar = store.defaultCalendarForNewEvents else { return }
            event.calendar = calendar
        }
        event.title = item.parent.map { "\($0.title): \(item.title)" } ?? item.title
        event.notes = item.notes.isEmpty ? nil : item.notes
        event.startDate = start
        event.endDate = end
        do {
            try store.save(event, span: .thisEvent)
            item.calendarEventID = event.eventIdentifier
        } catch {
            item.calendarEventID = nil
        }
    }

    func removeEvent(id: String) {
        guard hasAccess, let event = store.event(withIdentifier: id) else { return }
        try? store.remove(event, span: .thisEvent)
    }
}
