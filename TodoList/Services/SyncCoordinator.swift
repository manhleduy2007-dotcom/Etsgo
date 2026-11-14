import Foundation
import SwiftData
import SwiftUI

@MainActor
final class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()
    @Published var status = ""
    @Published var hasConflicts = false
    private var running = false
    private let api = BackendClient.shared
    private let formatter = ISO8601DateFormatter()

    func date(_ text: Any?) -> Date? {
        guard let text = text as? String else { return nil }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = formatter.date(from: text) { return value }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
    func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    func json(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
    func object(_ text: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] ?? [:]
    }
    private func singletonID(_ name: String) -> String {
        let key = "sync-id-" + name
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    func capture(_ db: ModelContext) throws {
        var values: [(String, String, [String: Any])] = []
        let tasks = try db.fetch(FetchDescriptor<TodoItem>())
        for task in tasks {
            task.uid = task.uid.lowercased()
            values.append(("task", task.uid, ["title": task.title, "notes": task.notes,
                "parent_id": task.parent?.uid as Any? ?? NSNull(), "order": task.order, "is_done": task.isDone,
                "due": task.dueDate.map(iso) as Any? ?? NSNull(), "priority": task.priority.apiName,
                "category": task.category.rawValue, "estimated_minutes": task.estimatedMinutes,
                "focus_minutes": task.focusMinutes, "break_minutes": task.breakMinutes,
                "remind": task.remind, "repeat_rule": task.repeatRaw, "is_stuck": task.isStuck]))
        }
        // Parents precede children so a newly created goal can be pushed in one pass.
        values.sort { ($0.2["parent_id"] is NSNull ? 0 : 1) < ($1.2["parent_id"] is NSNull ? 0 : 1) }
        for fact in try db.fetch(FetchDescriptor<ContextItem>()) {
            fact.uid = fact.uid.lowercased()
            values.append(("context", fact.uid, ["text": fact.text, "source": fact.sourceRaw, "confirmed": fact.confirmed,
                "scope": fact.scope, "scope_id": fact.scopeID as Any? ?? NSNull(),
                "valid_until": fact.validUntil.map(iso) as Any? ?? NSNull()]))
        }
        for focus in try db.fetch(FetchDescriptor<FocusSession>()) {
            focus.uid = focus.uid.lowercased()
            values.append(("focus", focus.uid, ["task_id": focus.taskID as Any? ?? NSNull(),
                "planned_id": NSNull(), "task_title": focus.taskTitle, "started_at": iso(focus.startedAt),
                "finished_at": focus.finishedAt.map(iso) as Any? ?? NSNull(), "focus_seconds": focus.focusSeconds,
                "outcome": focus.outcomeRaw]))
        }
        values.append(("profile", singletonID("profile"), ["language": AppLanguage.current.rawValue, "timezone": TimeZone.current.identifier]))
        let week = StudySchedule.load()
        let order = [1, 2, 3, 4, 5, 6, 0]
        let days: [[String: Any]] = order.map { index in
            let day = week[index]
            return ["windows": day.enabled ? [["start": day.startHour*60, "end": day.endHour*60]] : [],
                    "commitment": day.enabled ? day.commitMinutes : 0]
        }
        values.append(("week", singletonID("week"), ["days": days]))
        let today = DateFormatter(); today.dateFormat = "yyyy-MM-dd"; today.locale = Locale(identifier: "en_US_POSIX")
        let dayString = today.string(from: .now)
        values.append(("commitment", singletonID("commitment-"+dayString),
                       ["day": dayString, "minutes": StudySchedule.commitment(for: .now)]))
        let records = try db.fetch(FetchDescriptor<SyncRecord>())
        let pending = try db.fetch(FetchDescriptor<PendingOperation>())
        for (kind, id, payload) in values {
            let record = records.first { $0.kind == kind && $0.entityID == id } ?? {
                let value = SyncRecord(kind: kind, id: id); db.insert(value); return value
            }()
            let encoded = json(payload)
            if record.fingerprint != encoded && record.conflict.isEmpty && !record.deleted
                && !pending.contains(where: { $0.kind == kind && $0.entityID == id }) {
                db.insert(PendingOperation(kind: kind, id: id, version: record.version, action: "upsert", payload: encoded))
            }
        }
        for record in records where ["task", "context", "focus"].contains(record.kind) && !record.deleted && record.conflict.isEmpty {
            if !values.contains(where: { $0.0 == record.kind && $0.1 == record.entityID })
                && !pending.contains(where: { $0.kind == record.kind && $0.entityID == record.entityID }) {
                db.insert(PendingOperation(kind: record.kind, id: record.entityID, version: record.version, action: "delete", payload: "{}"))
            }
        }
        try db.save()
    }

    func sync(_ db: ModelContext) async {
        guard api.signedIn, !running else { return }
        running = true
        defer { running = false }
        do {
            if !UserDefaults.standard.bool(forKey: "syncInitialized") {
                var initialCursor = 0
                var boundary: Int?
                while true {
                    let response = try await api.request("GET", "/v1/sync/pull?cursor=\(initialCursor)" + (boundary.map { "&until=\($0)" } ?? ""))
                    boundary = response["until"] as? Int
                    for change in response["changes"] as? [[String: Any]] ?? [] { try apply(change, db: db) }
                    initialCursor = response["cursor"] as? Int ?? initialCursor
                    if response["has_more"] as? Bool != true { break }
                }
                try linkParents(db); try db.save()
                UserDefaults.standard.set(initialCursor, forKey: "syncCursor")
                UserDefaults.standard.set(true, forKey: "syncInitialized")
            }
            try capture(db)
            let pending = try db.fetch(FetchDescriptor<PendingOperation>(sortBy: [SortDescriptor(\.createdAt)]))
            for operation in pending {
                let body: [String: Any] = ["operation_id": operation.operationID, "entity_type": operation.kind,
                    "entity_id": operation.entityID, "action": operation.action,
                    "expected_version": operation.expectedVersion, "payload": object(operation.payload)]
                let response = try await api.request("POST", "/v1/sync/push", ["operations": [body]])
                guard let result = (response["results"] as? [[String: Any]])?.first else { throw BackendFailure(code: "invalid_sync_response") }
                let records = try db.fetch(FetchDescriptor<SyncRecord>())
                guard let record = records.first(where: { $0.kind == operation.kind && $0.entityID == operation.entityID }) else { continue }
                if result["status"] as? String == "conflict" {
                    record.conflict = json(result["current"] as? [String: Any] ?? [:])
                    hasConflicts = true
                    try db.save()
                    throw BackendFailure(code: "sync_conflict_review_in_settings")
                }
                guard result["status"] as? String == "applied" else { throw BackendFailure(code: result["code"] as? String ?? "sync_failed") }
                let entity = result["entity"] as? [String: Any] ?? [:]
                record.version = entity["version"] as? Int ?? record.version
                record.fingerprint = operation.payload
                record.deleted = operation.action == "delete"
                db.delete(operation)
                try db.save()
            }
            try capture(db) // Edits made while awaiting push are queued before pull.
            var cursor = UserDefaults.standard.integer(forKey: "syncCursor")
            var until: Int?
            while true {
                let response = try await api.request("GET", "/v1/sync/pull?cursor=\(cursor)" + (until.map { "&until=\($0)" } ?? ""))
                until = response["until"] as? Int
                let changes = response["changes"] as? [[String: Any]] ?? []
                for change in changes { try apply(change, db: db) }
                // Re-link parent relationships after all task rows in this page exist.
                try linkParents(db)
                try db.save()
                cursor = response["cursor"] as? Int ?? cursor
                UserDefaults.standard.set(cursor, forKey: "syncCursor")
                if response["has_more"] as? Bool != true { break }
            }
            status = L("Đã đồng bộ", "Synced")
            hasConflicts = try db.fetch(FetchDescriptor<SyncRecord>()).contains { !$0.conflict.isEmpty }
        } catch { status = error.localizedDescription }
    }

    func apply(_ change: [String: Any], db: ModelContext) throws {
        guard let kind = change["entity_type"] as? String, let id = change["entity_id"] as? String,
              let payload = change["payload"] as? [String: Any], let version = change["version"] as? Int else { return }
        let records = try db.fetch(FetchDescriptor<SyncRecord>())
        let record = records.first { $0.kind == kind && $0.entityID == id } ?? {
            let row = SyncRecord(kind: kind, id: id); db.insert(row); return row
        }()
        if version <= record.version { return }
        let operations = try db.fetch(FetchDescriptor<PendingOperation>())
        if operations.contains(where: { $0.kind == kind && $0.entityID == id }) {
            record.conflict = json(change); hasConflicts = true; return
        }
        let deleted = change["deleted"] as? Bool ?? false
        if kind == "task" {
            let all = try db.fetch(FetchDescriptor<TodoItem>())
            let item = all.first { $0.uid == id } ?? { let t = TodoItem(title: ""); t.uid = id; db.insert(t); return t }()
            if deleted { db.delete(item) }
            else {
                item.title = payload["title"] as? String ?? ""
                item.notes = payload["notes"] as? String ?? ""
                item.isDone = payload["is_done"] as? Bool ?? false
                item.dueDate = date(payload["due"])
                item.priority = Priority(apiName: payload["priority"] as? String ?? "medium") ?? .medium
                item.categoryRaw = payload["category"] as? String ?? "study"
                item.order = payload["order"] as? Int ?? 0
                item.estimatedMinutes = payload["estimated_minutes"] as? Int ?? 30
                item.focusMinutes = payload["focus_minutes"] as? Int ?? 25
                item.breakMinutes = payload["break_minutes"] as? Int ?? 5
                item.remind = payload["remind"] as? Bool ?? false
                item.repeatRaw = payload["repeat_rule"] as? String ?? "none"
                item.isStuck = payload["is_stuck"] as? Bool ?? false
                NotificationService.scheduleReminder(for: item)
            }
        } else if kind == "context" {
            let all = try db.fetch(FetchDescriptor<ContextItem>())
            let fact = all.first { $0.uid == id } ?? { let f = ContextItem(text: "", source: "user", confirmed: true); f.uid = id; db.insert(f); return f }()
            if deleted { db.delete(fact) }
            else {
                fact.text = payload["text"] as? String ?? ""
                fact.sourceRaw = payload["source"] as? String ?? "user"
                fact.confirmed = payload["confirmed"] as? Bool ?? false
                fact.scope = payload["scope"] as? String ?? "personal"
                fact.scopeID = payload["scope_id"] as? String
                fact.validUntil = date(payload["valid_until"])
            }
        } else if kind == "planned" {
            let all = try db.fetch(FetchDescriptor<PlannedSession>())
            if let old = all.first(where: { $0.uid == id }) { db.delete(old) }
            if !deleted, let start = date(payload["start"]), let end = date(payload["end"]), let taskID = payload["task_id"] as? String {
                db.insert(PlannedSession(id: id, taskID: taskID, start: start, end: end,
                    focus: payload["focus_minutes"] as? Int ?? 25, rest: payload["break_minutes"] as? Int ?? 5, version: version))
            }
        } else if kind == "profile" {
            UserDefaults.standard.set(id, forKey: "sync-id-profile")
            UserDefaults.standard.set(payload["language"] as? String ?? "vi", forKey: "language")
        } else if kind == "week", let days = payload["days"] as? [[String: Any]], days.count == 7 {
            UserDefaults.standard.set(id, forKey: "sync-id-week")
            var week = StudySchedule.load()
            for index in 0..<7 {
                let day = days[index]; let windows = day["windows"] as? [[String: Any]] ?? []
                let window = windows.first
                week[(index+1)%7] = DayPlan(enabled: !windows.isEmpty, startHour: (window?["start"] as? Int ?? 1140)/60,
                    endHour: (window?["end"] as? Int ?? 1320)/60, commitMinutes: day["commitment"] as? Int ?? 60)
            }
            StudySchedule.save(week)
        } else if kind == "commitment", let day = payload["day"] as? String {
            UserDefaults.standard.set(id, forKey: "sync-id-commitment-"+day)
            UserDefaults.standard.set(payload["minutes"] as? Int ?? 0, forKey: "commit-"+day)
        } else if kind == "focus" {
            let all = try db.fetch(FetchDescriptor<FocusSession>())
            let focus = all.first { $0.uid == id } ?? { let f = FocusSession(taskTitle: "", focusSeconds: 0); f.uid = id; db.insert(f); return f }()
            if deleted { db.delete(focus) }
            else {
                focus.taskTitle = payload["task_title"] as? String ?? ""
                focus.taskID = payload["task_id"] as? String
                focus.startedAt = date(payload["started_at"]) ?? .now
                focus.finishedAt = date(payload["finished_at"])
                focus.focusSeconds = payload["focus_seconds"] as? Int ?? 0
                focus.outcomeRaw = payload["outcome"] as? String ?? "ended"
            }
        }
        record.version = version; record.fingerprint = json(payload); record.deleted = deleted
    }

    private func linkParents(_ db: ModelContext) throws {
        let tasks = try db.fetch(FetchDescriptor<TodoItem>())
        for record in try db.fetch(FetchDescriptor<SyncRecord>()) where record.kind == "task" && !record.deleted {
            guard let task = tasks.first(where: { $0.uid == record.entityID }) else { continue }
            let parentID = object(record.fingerprint)["parent_id"] as? String
            task.parent = tasks.first { $0.uid == parentID }
        }
    }

    func resolve(_ db: ModelContext, keepLocal: Bool) throws {
        for record in try db.fetch(FetchDescriptor<SyncRecord>()) where !record.conflict.isEmpty {
            let remote = object(record.conflict)
            for op in try db.fetch(FetchDescriptor<PendingOperation>()) where op.kind == record.kind && op.entityID == record.entityID { db.delete(op) }
            record.conflict = ""
            if keepLocal && remote["deleted"] as? Bool != true {
                record.version = remote["version"] as? Int ?? 0
                record.fingerprint = ""
            } else {
                record.version = 0
                // Suppress re-capture of the local edit while choosing server.
                record.fingerprint = try localFingerprint(record, db: db)
                try apply(remote, db: db)
            }
        }
        try db.save(); hasConflicts = false
    }

    private func localFingerprint(_ record: SyncRecord, db: ModelContext) throws -> String {
        // Capture into an operation, then discard it to establish the local baseline.
        try capture(db)
        let op = try db.fetch(FetchDescriptor<PendingOperation>()).first { $0.kind == record.kind && $0.entityID == record.entityID }
        let result = op?.payload ?? record.fingerprint
        if let op { db.delete(op) }
        return result
    }
}
