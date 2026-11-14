import SwiftUI
import SwiftData

/// Lịch làm việc do bộ xếp lịch tự động tạo ra.
struct ScheduleView: View {
    @Query private var allItems: [TodoItem]

    @AppStorage("workStartHour") private var startHour = 9
    @AppStorage("workEndHour") private var endHour = 18
    @AppStorage("syncCalendar") private var syncCalendar = false

    @State private var message: String?

    /// Đơn vị được xếp lịch: việc chưa xong và không có bước nhỏ (hoặc chính là một bước nhỏ).
    private var schedulable: [TodoItem] {
        allItems.filter { !$0.isDone && $0.subtasks.isEmpty && $0.parent?.isDone != true }
    }

    private var scheduled: [TodoItem] {
        schedulable
            .filter { $0.scheduledStart != nil }
            .sorted { ($0.scheduledStart ?? .distantFuture) < ($1.scheduledStart ?? .distantFuture) }
    }

    private var unscheduled: [TodoItem] {
        schedulable.filter { $0.scheduledStart == nil }
    }

    private var days: [(day: Date, items: [TodoItem])] {
        let groups = Dictionary(grouping: scheduled) {
            Calendar.current.startOfDay(for: $0.scheduledStart ?? .now)
        }
        return groups.keys.sorted().map { (day: $0, items: groups[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Tự động xếp vào giờ trống")
                    Text("Lịch")
                        .font(Theme.display)
                        .tracking(-0.6)
                        .foregroundStyle(Theme.ink)
                }
                .padding(.top, 16)
                .padding(.bottom, 6)

                Button {
                    autoSchedule()
                } label: {
                    Label("Tự động xếp lịch", systemImage: "calendar.badge.checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.onMark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.mark, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(schedulable.isEmpty)
                .opacity(schedulable.isEmpty ? 0.45 : 1)

                Text(
                    "Xếp việc chưa xong vào khung \(startHour):00–\(endHour):00 trong \(Scheduler.horizonDays) ngày tới. "
                        + "Ưu tiên cao và hạn gần được xếp trước"
                        + (syncCalendar ? ", tránh các sự kiện đã có trong Lịch." : ".")
                )
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)

                if let message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.ink, lineWidth: 1.5))
                        .onTapGesture { self.message = nil }
                }

                ForEach(days, id: \.day) { group in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(group.day.formatted(.dateTime.weekday(.wide)))
                            .font(Theme.dayTitle)
                            .foregroundStyle(Theme.ink)
                        Text(group.day.formatted(.dateTime.day().month(.wide)))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 12)

                    ForEach(group.items) { item in
                        ScheduleBlock(item: item)
                    }
                }

                if !unscheduled.isEmpty {
                    Eyebrow(text: "Chưa xếp lịch (\(unscheduled.count))")
                        .padding(.top, 12)
                    ForEach(unscheduled) { item in
                        ScheduleBlock(item: item)
                    }
                }

                if !scheduled.isEmpty {
                    Button("Xoá lịch đã xếp", role: .destructive) {
                        clearSchedule()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.red)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                }

                if schedulable.isEmpty {
                    VStack(spacing: 4) {
                        Text("Không có việc để xếp")
                            .font(Theme.dayTitle)
                            .foregroundStyle(Theme.ink)
                        Text("Thêm việc ở tab Công việc rồi quay lại đây.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func autoSchedule() {
        let now = Date.now
        let calendarService = CalendarService.shared
        let useCalendar = syncCalendar && calendarService.hasAccess
        let tasks = schedulable

        var busy: [DateInterval] = []
        if useCalendar {
            let horizon = now.addingTimeInterval(TimeInterval(Scheduler.horizonDays + 1) * 86400)
            busy = calendarService.busyIntervals(
                from: now,
                to: horizon,
                excluding: Set(allItems.compactMap(\.calendarEventID))
            )
        }

        let result = Scheduler.plan(tasks: tasks, busy: busy, from: now, startHour: startHour, endHour: endHour)
        for task in tasks { task.scheduledStart = nil }
        for assignment in result.assignments { assignment.item.scheduledStart = assignment.start }
        if useCalendar {
            for task in tasks { calendarService.sync(task) }
        }

        var text = "Đã xếp \(result.assignments.count) việc"
        text += useCalendar ? " và ghi vào Lịch." : "."
        if !result.unscheduled.isEmpty {
            text += " \(result.unscheduled.count) việc không tìm được chỗ trống (việc dài hơn khung giờ làm trong ngày thì cần chia nhỏ)."
        }
        if syncCalendar && !calendarService.hasAccess {
            text += " Chưa có quyền truy cập Lịch nên không đồng bộ."
        }
        message = text
    }

    private func clearSchedule() {
        for task in allItems where task.scheduledStart != nil {
            task.scheduledStart = nil
            CalendarService.shared.sync(task)
        }
        message = nil
    }
}

/// Một khối công việc trên lịch, tô nền theo màu nhóm.
private struct ScheduleBlock: View {
    let item: TodoItem

    var body: some View {
        let category = item.effectiveCategory
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                if let start = item.scheduledStart, let end = item.scheduledEnd {
                    Text(start.formatted(date: .omitted, time: .shortened))
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.ink)
                    Text(end.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(Theme.muted)
                }
            }
            .font(.system(size: 13).monospacedDigit())
            .frame(width: 58, alignment: .trailing)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let parent = item.parent {
                    Text(parent.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                FlowLayout(spacing: 6) {
                    if item.effectivePriorityRaw == Priority.high.rawValue {
                        TagView(text: "Ưu tiên cao", style: .highlight)
                    }
                    TagView(text: category.title, style: .category(category.color))
                    TagView(text: durationText(item.estimatedMinutes))
                    if let due = item.effectiveDueDate {
                        // Đỏ khi giờ kết thúc đã xếp vượt quá hạn chót.
                        TagView(
                            text: "Hạn " + shortDateText(due),
                            style: (item.scheduledEnd ?? .now) > due ? .late : .plain
                        )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(category.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ScheduleView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
