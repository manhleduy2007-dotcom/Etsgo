import Foundation

/// Khung giờ học mặc định của một ngày trong tuần và thời gian muốn cam kết.
struct DayPlan: Codable, Equatable {
    var enabled: Bool
    var startHour: Int
    var endHour: Int
    /// Thời gian cam kết, tính cả giờ nghỉ (tổng thời gian chiếm trên lịch).
    var commitMinutes: Int
}

/// Lịch học tuần (mặc định) và cam kết theo từng ngày (SC-01).
/// Khung giờ là khoảng CÓ THỂ xếp; cam kết là phần người dùng đồng ý dành cho việc học.
enum StudySchedule {
    private static let key = "weeklySchedule"

    /// Chỉ số 0 = Chủ nhật ... 6 = Thứ bảy.
    static func load() -> [DayPlan] {
        if let data = UserDefaults.standard.data(forKey: key),
           let week = try? JSONDecoder().decode([DayPlan].self, from: data),
           week.count == 7 {
            return week
        }
        return Array(repeating: DayPlan(enabled: true, startHour: 19, endHour: 22, commitMinutes: 60), count: 7)
    }

    static func save(_ week: [DayPlan]) {
        let cleaned = week.map { day -> DayPlan in
            var day = day
            day.commitMinutes = min(max(day.commitMinutes, 15), (day.endHour - day.startHour) * 60)
            return day
        }
        if let data = try? JSONEncoder().encode(cleaned) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func plan(for date: Date, calendar: Calendar = .current) -> DayPlan {
        load()[calendar.component(.weekday, from: date) - 1]
    }

    private static func overrideKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "commit-" + formatter.string(from: date)
    }

    /// Cam kết của một ngày: số người dùng đã xác nhận cho ngày đó, nếu không thì theo lịch tuần.
    static func commitment(for date: Date) -> Int {
        let dayKey = overrideKey(for: date)
        if UserDefaults.standard.object(forKey: dayKey) != nil {
            return UserDefaults.standard.integer(forKey: dayKey)
        }
        let plan = plan(for: date)
        return plan.enabled ? plan.commitMinutes : 0
    }

    /// Cam kết của một ngày không kéo thành sở thích lâu dài: chỉ lưu cho đúng ngày đó.
    static func setCommitment(_ minutes: Int, for date: Date) {
        UserDefaults.standard.set(max(minutes, 0), forKey: overrideKey(for: date))
    }

    static func weekdayName(_ index: Int) -> String {
        var calendar = Calendar.current
        calendar.locale = AppLanguage.current.locale
        return calendar.standaloneWeekdaySymbols[index].capitalized
    }

    /// Tóm tắt gửi cho AI khi lập kế hoạch.
    static func promptSummary() -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return load().enumerated().map { index, day in
            day.enabled
                ? "\(names[index]): \(day.startHour):00-\(day.endHour):00, commits \(day.commitMinutes) min"
                : "\(names[index]): no study"
        }.joined(separator: "; ")
    }
}
