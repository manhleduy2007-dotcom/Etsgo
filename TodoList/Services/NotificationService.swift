import Foundation
import UserNotifications

/// Lời nhắc việc và thông báo hết phiên Pomodoro khi app ở nền.
enum NotificationService {
    static func requestAccess() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(id: String, title: String, body: String, at date: Date) {
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSinceNow, 1), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Nhắc vào giờ đã xếp, nếu chưa xếp thì vào hạn chót.
    @MainActor
    static func scheduleReminder(for item: TodoItem) {
        cancel(item.uid)
        guard item.remind, !item.isDone, let date = item.scheduledStart ?? item.dueDate else { return }
        schedule(id: item.uid, title: item.title, body: L("Đến giờ cho việc này.", "It's time for this task."), at: date)
    }
}
