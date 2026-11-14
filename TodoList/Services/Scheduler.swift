import Foundation

/// Xếp công việc vào các khoảng trống trong giờ làm việc, tránh các khoảng đã bận.
enum Scheduler {
    struct Result {
        var assignments: [(item: TodoItem, start: Date)] = []
        var unscheduled: [TodoItem] = []
    }

    static let horizonDays = 14

    /// Việc ưu tiên cao được chọn chỗ trước, sau đó đến việc có hạn chót gần hơn.
    @MainActor
    static func plan(
        tasks: [TodoItem],
        busy: [DateInterval],
        from now: Date = .now,
        startHour: Int,
        endHour: Int,
        calendar: Calendar = .current
    ) -> Result {
        let ordered = tasks.sorted { a, b in
            if a.effectivePriorityRaw != b.effectivePriorityRaw {
                return a.effectivePriorityRaw > b.effectivePriorityRaw
            }
            switch (a.effectiveDueDate, b.effectiveDueDate) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default:
                if a.parent != nil, a.parent === b.parent { return a.order < b.order }
                return a.createdAt < b.createdAt
            }
        }

        // Làm tròn lên mốc 15 phút kế tiếp.
        let step: TimeInterval = 15 * 60
        let earliest = Date(
            timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / step).rounded(.up) * step
        )
        let today = calendar.startOfDay(for: now)

        var occupied = busy
        var result = Result()

        for task in ordered {
            let duration = TimeInterval(max(task.estimatedMinutes, 15) * 60)
            var slot: Date?

            for dayOffset in 0..<horizonDays {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
                let windowStart = max(day.addingTimeInterval(TimeInterval(startHour) * 3600), earliest)
                let windowEnd = day.addingTimeInterval(TimeInterval(endHour) * 3600)
                if let found = firstGap(of: duration, from: windowStart, to: windowEnd, avoiding: occupied) {
                    slot = found
                    break
                }
            }

            if let slot {
                occupied.append(DateInterval(start: slot, duration: duration))
                result.assignments.append((task, slot))
            } else {
                result.unscheduled.append(task)
            }
        }
        return result
    }

    private static func firstGap(
        of duration: TimeInterval,
        from windowStart: Date,
        to windowEnd: Date,
        avoiding occupied: [DateInterval]
    ) -> Date? {
        var cursor = windowStart
        for interval in occupied.sorted(by: { $0.start < $1.start }) {
            if cursor.addingTimeInterval(duration) > windowEnd { return nil }
            if interval.end <= cursor { continue }
            if interval.start >= cursor.addingTimeInterval(duration) { return cursor }
            cursor = interval.end
        }
        return cursor.addingTimeInterval(duration) <= windowEnd ? cursor : nil
    }
}
