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
        NavigationStack {
            List {
                Section {
                    Button {
                        autoSchedule()
                    } label: {
                        Label("Tự động xếp lịch", systemImage: "wand.and.stars")
                    }
                    .disabled(schedulable.isEmpty)

                    if !scheduled.isEmpty {
                        Button("Xoá lịch đã xếp", systemImage: "calendar.badge.minus", role: .destructive) {
                            clearSchedule()
                        }
                    }
                } footer: {
                    Text(
                        "Xếp các việc chưa xong vào khung \(startHour):00–\(endHour):00 trong \(Scheduler.horizonDays) ngày tới, "
                            + "ưu tiên cao và hạn gần được xếp trước"
                            + (syncCalendar ? ", tránh các sự kiện đã có trong Lịch." : ".")
                    )
                }

                ForEach(days, id: \.day) { group in
                    Section(group.day.formatted(.dateTime.weekday(.wide).day().month())) {
                        ForEach(group.items) { item in
                            ScheduleRow(item: item)
                        }
                    }
                }

                if !unscheduled.isEmpty {
                    Section("Chưa xếp lịch (\(unscheduled.count))") {
                        ForEach(unscheduled) { item in
                            ScheduleRow(item: item)
                        }
                    }
                }
            }
            .overlay {
                if schedulable.isEmpty {
                    ContentUnavailableView(
                        "Không có việc để xếp",
                        systemImage: "calendar",
                        description: Text("Thêm công việc ở tab Công việc rồi quay lại đây.")
                    )
                    .padding(.top, 120)
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Lịch")
            .alert(
                "Xếp lịch",
                isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
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
    }
}

private struct ScheduleRow: View {
    let item: TodoItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let start = item.scheduledStart, let end = item.scheduledEnd {
                VStack(alignment: .trailing) {
                    Text(start.formatted(date: .omitted, time: .shortened))
                    Text(end.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.monospacedDigit())
                .frame(width: 64, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                if let parent = item.parent {
                    Text(parent.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("\(item.estimatedMinutes) phút")
                    if let due = item.effectiveDueDate {
                        Text("Hạn: " + due.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(lateColor(due))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if item.effectivePriorityRaw == Priority.high.rawValue {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Ưu tiên cao")
            }
        }
    }

    /// Đỏ khi giờ kết thúc đã xếp vượt quá hạn chót.
    private func lateColor(_ due: Date) -> Color {
        (item.scheduledEnd ?? .now) > due ? .red : .secondary
    }
}

#Preview {
    ScheduleView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
