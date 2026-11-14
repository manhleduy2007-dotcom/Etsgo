import Foundation
import SwiftData

@Model
final class SyncRecord {
    var kind: String
    var entityID: String
    var version: Int = 0
    var fingerprint: String = ""
    var deleted: Bool = false
    var conflict: String = ""
    init(kind: String, id: String) { self.kind = kind; entityID = id }
}

@Model
final class PendingOperation {
    var operationID: String = UUID().uuidString.lowercased()
    var kind: String
    var entityID: String
    var expectedVersion: Int
    var action: String
    var payload: String
    var createdAt: Date = Date.now
    init(kind: String, id: String, version: Int, action: String, payload: String) {
        self.kind = kind; entityID = id; expectedVersion = version
        self.action = action; self.payload = payload
    }
}

@Model
final class PlannedSession {
    var uid: String
    var taskID: String
    var start: Date
    var end: Date
    var focusMinutes: Int
    var breakMinutes: Int
    var version: Int
    init(id: String, taskID: String, start: Date, end: Date, focus: Int, rest: Int, version: Int) {
        uid = id; self.taskID = taskID; self.start = start; self.end = end
        focusMinutes = focus; breakMinutes = rest; self.version = version
    }
}
