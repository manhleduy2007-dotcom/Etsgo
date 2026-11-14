import Foundation

/// Đề xuất phiên học trong khung giờ của lịch tuần, không vượt thời gian cam kết của từng ngày,
/// tránh các khoảng đã bận và giữ đúng thứ tự các bước (SC-02).
enum Scheduler {
    enum Reason {
        /// Việc dài hơn thời gian cam kết của mọi ngày: cần chia nhỏ hoặc tăng cam kết.
        case longerThanCommitment
        /// Không còn chỗ trong các ngày tới.
        case noRoom
    }

    struct Result {
        var assignments: [(item: TodoItem, start: Date)] = []
        var unscheduled: [(item: TodoItem, reason: Reason)] = []
    }

    static let horizonDays = 14

    /// Việc ưu tiên cao được chọn chỗ trước, sau đó đến việc có hạn chót gần hơn.
    /// Không tự kéo dài giờ học: việc không vừa cam kết sẽ nằm trong `unscheduled`.
    @MainActor
    static func plan(
        tasks: [TodoItem],
        busy: [DateInterval],
        from now: Date = .now,
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
        let week = StudySchedule.load()

        var days: [(start: Date, plan: DayPlan)] = []
        var budget: [Int] = []
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            days.append((day, week[calendar.component(.weekday, from: day) - 1]))
            budget.append(StudySchedule.commitment(for: day))
        }
        let largestCommitment = budget.max() ?? 0

        var occupied = busy
        var notBefore: [ObjectIdentifier: Date] = [:]
        var result = Result()

        for task in ordered {
            let minutes = max(task.estimatedMinutes, 15)
            let duration = TimeInterval(minutes * 60)
            guard minutes <= largestCommitment else {
                result.unscheduled.append((task, .longerThanCommitment))
                continue
            }

            // Bước sau không được xếp trước khi bước trước kết thúc.
            var floor = earliest
            if let parent = task.parent, let previousEnd = notBefore[ObjectIdentifier(parent)] {
                floor = max(floor, previousEnd)
            }

            var slot: Date?
            for index in days.indices where budget[index] >= minutes {
                let day = days[index]
                let windowStart = max(day.start.addingTimeInterval(TimeInterval(day.plan.startHour) * 3600), floor)
                let windowEnd = day.start.addingTimeInterval(TimeInterval(day.plan.endHour) * 3600)
                if let found = firstGap(of: duration, from: windowStart, to: windowEnd, avoiding: occupied) {
                    slot = found
                    budget[index] -= minutes
                    break
                }
            }

            if let slot {
                occupied.append(DateInterval(start: slot, duration: duration))
                result.assignments.append((task, slot))
                if let parent = task.parent {
                    notBefore[ObjectIdentifier(parent)] = slot.addingTimeInterval(duration)
                }
            } else {
                result.unscheduled.append((task, .noRoom))
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
