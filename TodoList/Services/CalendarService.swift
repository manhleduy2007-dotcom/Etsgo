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

    func calendars() -> [(id: String, title: String)] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event).filter { $0.title != "Etsgo" }.map { ($0.calendarIdentifier, $0.source.title+" / "+$0.title) }
    }

    func publishBusy() async throws {
        guard hasAccess else { throw BackendFailure(code: "calendar_permission_required") }
        let api = BackendClient.shared
        let state = try await api.request("GET", "/v1/calendar/status")
        let selected = UserDefaults.standard.stringArray(forKey: "eventkitReadCalendars")
        if state["google_connected"] as? Bool == true && selected == nil {
            throw BackendFailure(code: "select_eventkit_calendars_excluding_direct_google_in_settings")
        }
        let calendars = store.calendars(for: .event).filter { calendar in
            calendar.title != "Etsgo" && (selected == nil || selected!.contains(calendar.calendarIdentifier))
        }
        let start = Date.now, end = start.addingTimeInterval(16*86400)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let intervals = calendars.isEmpty ? [] : store.events(matching: predicate).filter {
            $0.availability != .free && $0.status != .canceled && $0.endDate > $0.startDate
        }.map { ["start": SyncCoordinator.shared.iso($0.startDate), "end": SyncCoordinator.shared.iso($0.endDate)] }
        _ = try await api.request("POST", "/v1/calendar/eventkit/snapshots",
            ["device_id": api.deviceID, "intervals": intervals])
    }

    func executeActions() async throws {
        guard hasAccess else { throw BackendFailure(code: "calendar_permission_required") }
        let api = BackendClient.shared
        let response = try await api.request("GET", "/v1/calendar/actions?device_id="+api.deviceID)
        for action in response["actions"] as? [[String: Any]] ?? [] {
            guard let id = action["id"] as? String,
                  let start = SyncCoordinator.shared.date(action["start"]), let end = SyncCoordinator.shared.date(action["end"]) else { continue }
            let marker = "etsgo:"+id
            let predicate = store.predicateForEvents(withStart: start.addingTimeInterval(-365*86400),
                end: end.addingTimeInterval(365*86400), calendars: nil)
            let existing = store.events(matching: predicate).first { $0.notes?.contains(marker) == true }
            if action["action"] as? String == "delete" {
                if let existing { try store.remove(existing, span: .thisEvent) }
                _ = try await api.request("POST", "/v1/calendar/actions/"+id+"/result",
                    ["device_id": api.deviceID, "external_id": existing?.eventIdentifier ?? "", "revision": action["revision"] as? Int ?? 1])
                continue
            }
            let event = existing ?? EKEvent(eventStore: store)
            if let existing, abs(existing.startDate.timeIntervalSince(start)) > 1 || abs(existing.endDate.timeIntervalSince(end)) > 1 {
                guard let oldStart = SyncCoordinator.shared.date(action["previous_start"]),
                      let oldEnd = SyncCoordinator.shared.date(action["previous_end"]),
                      abs(existing.startDate.timeIntervalSince(oldStart)) < 1,
                      abs(existing.endDate.timeIntervalSince(oldEnd)) < 1 else {
                    throw BackendFailure(code: "calendar_reconcile_required")
                }
            }
            if existing == nil {
                let selectedID = UserDefaults.standard.string(forKey: "eventkitOutputCalendar")
                let old = selectedID.flatMap { store.calendar(withIdentifier: $0) }
                if let old { event.calendar = old }
                else {
                    guard let source = store.defaultCalendarForNewEvents?.source else { throw BackendFailure(code: "calendar_not_writable") }
                    let output = EKCalendar(for: .event, eventStore: store)
                    output.title = "Etsgo"; output.source = source
                    try store.saveCalendar(output, commit: true)
                    UserDefaults.standard.set(output.calendarIdentifier, forKey: "eventkitOutputCalendar")
                    event.calendar = output
                }
            }
            event.title = action["title"] as? String ?? "Etsgo"
            event.notes = marker
            event.startDate = start; event.endDate = end
            try store.save(event, span: .thisEvent)
            _ = try await api.request("POST", "/v1/calendar/actions/"+id+"/result",
                ["device_id": api.deviceID, "external_id": event.eventIdentifier ?? "", "revision": action["revision"] as? Int ?? 1])
        }
    }
}
