import SwiftUI
import SwiftData

/// Lịch học: xác nhận cam kết hôm nay, xem đề xuất, sửa rồi duyệt. Không có gì được áp dụng
/// hay ghi ra Lịch ngoài khi người dùng chưa duyệt (SC-04).
struct ScheduleView: View {
    private struct Entry: Identifiable {
        let id = UUID()
        let item: TodoItem
        let start: Date
    }

    private struct Proposal {
        var entries: [Entry]
        var unscheduled: [(item: TodoItem, reason: Scheduler.Reason)]
    }

    @Query private var allItems: [TodoItem]
    @AppStorage("syncCalendar") private var syncCalendar = false

    @State private var todayCommit = StudySchedule.commitment(for: .now)
    @State private var proposal: Proposal?
    @State private var message: String?
    @State private var confirmCalendarWrite = false
    @State private var confirmClear = false
    @State private var startingItem: TodoItem?

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

    private var missed: [TodoItem] {
        scheduled.filter(\.isMissed)
    }

    private var calendarConnected: Bool {
        syncCalendar && CalendarService.shared.hasAccess
    }

    /// Các phiên đã duyệt mà Lịch ngoài chưa khớp.
    private var pendingCalendarItems: [TodoItem] {
        guard calendarConnected else { return [] }
        return schedulable.filter { ($0.scheduledStart != nil) != ($0.calendarEventID != nil) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: L("Trong thời gian bạn cam kết", "Within the time you commit"))
                    Text(L("Lịch", "Schedule"))
                        .font(Theme.display)
                        .tracking(-0.6)
                        .foregroundStyle(Theme.ink)
                }
                .padding(.top, 16)
                .padding(.bottom, 6)

                commitmentCard

                if !calendarConnected {
                    // Lịch chưa kết nối hoặc lỗi không được hiểu là "không bận".
                    Text(L(
                        "Lịch ngoài chưa được tính: các phiên đề xuất có thể trùng sự kiện của bạn. Kết nối trong Cài đặt, hoặc chỉnh khung giờ học tuần cho khớp.",
                        "Your outside calendar is not being considered: proposed sessions may clash with your events. Connect it in Settings, or adjust your weekly study hours to match."
                    ))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                }

                if let message {
                    Banner(text: message).onTapGesture { self.message = nil }
                }

                if let proposal {
                    proposalView(proposal)
                } else {
                    approvedView
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .fullScreenCover(item: $startingItem) { item in
            PomodoroView(item: item)
        }
        .confirmationDialog(
            L(
                "Ghi \(pendingCalendarItems.count) thay đổi vào ứng dụng Lịch?",
                "Write \(pendingCalendarItems.count) changes to the Calendar app?"
            ),
            isPresented: $confirmCalendarWrite,
            titleVisibility: .visible
        ) {
            Button(L("Ghi vào Lịch", "Write to Calendar")) { writeToCalendar() }
            Button(L("Không", "Not now"), role: .cancel) {}
        }
        .confirmationDialog(
            L("Xoá toàn bộ lịch đã duyệt?", "Clear the whole approved schedule?"),
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button(L("Xoá lịch", "Clear schedule"), role: .destructive) { clearSchedule() }
            Button(L("Không", "Cancel"), role: .cancel) {}
        } message: {
            Text(L(
                "Các sự kiện ứng dụng đã ghi vào Lịch cũng sẽ bị xoá.",
                "Events this app wrote to Calendar will be removed too."
            ))
        }
    }

    // MARK: - Cam kết hôm nay (SC-01)

    private var commitmentCard: some View {
        let plan = StudySchedule.plan(for: .now)
        return VStack(alignment: .leading, spacing: 10) {
            Stepper(
                L("Hôm nay cam kết: ", "Today I commit: ") + durationText(todayCommit),
                value: $todayCommit, in: 0...((plan.endHour - plan.startHour) * 60), step: 15
            )
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .onChange(of: todayCommit) { _, minutes in
                StudySchedule.setCommitment(minutes, for: .now)
            }

            Text(L(
                "Khung giờ học hôm nay: \(plan.startHour):00–\(plan.endHour):00. Thời gian cam kết đã gồm giờ nghỉ. Ứng dụng không xếp quá số này và không tự tăng nó.",
                "Today's study window: \(plan.startHour):00–\(plan.endHour):00. Committed time includes breaks. The app never plans beyond it and never raises it for you."
            ))
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)

            Button {
                propose()
            } label: {
                PrimaryLabel(
                    title: scheduled.isEmpty ? L("Đề xuất lịch học", "Propose a schedule") : L("Đề xuất lại lịch", "Propose again"),
                    systemImage: "calendar.badge.checkmark"
                )
            }
            .buttonStyle(.plain)
            .disabled(schedulable.isEmpty)
            .opacity(schedulable.isEmpty ? 0.45 : 1)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Đề xuất chờ duyệt

    private func proposalView(_ current: Proposal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: L("Đề xuất, chưa áp dụng", "Proposal, not applied yet"))
                .padding(.top, 8)

            ForEach(current.entries) { entry in
                HStack(alignment: .top, spacing: 8) {
                    SessionBlock(
                        item: entry.item,
                        start: entry.start,
                        note: changeNote(for: entry),
                        showDay: true
                    )
                    Button {
                        proposal?.entries.removeAll { $0.id == entry.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 28, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Bỏ phiên này khỏi đề xuất", "Remove this session from the proposal"))
                }
            }

            if !current.unscheduled.isEmpty {
                Eyebrow(text: L("Chưa xếp được", "Could not be planned") + " (\(current.unscheduled.count))")
                    .padding(.top, 8)
                ForEach(Array(current.unscheduled.enumerated()), id: \.offset) { _, pair in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pair.item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(reasonText(pair.reason, minutes: pair.item.estimatedMinutes))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                }
            }

            Button {
                approve()
            } label: {
                PrimaryLabel(title: L("Duyệt lịch này", "Approve this schedule"), systemImage: "checkmark")
            }
            .buttonStyle(.plain)
            .disabled(current.entries.isEmpty)
            .opacity(current.entries.isEmpty ? 0.45 : 1)

            Button(L("Bỏ đề xuất, giữ lịch cũ", "Discard, keep the current schedule")) {
                proposal = nil
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
        }
    }

    /// Cho thấy phần thay đổi so với lịch đang có trước khi người dùng duyệt (AD-01).
    private func changeNote(for entry: Entry) -> String? {
        guard let old = entry.item.scheduledStart else { return L("Mới", "New") }
        if abs(old.timeIntervalSince(entry.start)) < 60 { return nil }
        return L("Trước đây: ", "Was: ") + shortDateText(old)
    }

    private func reasonText(_ reason: Scheduler.Reason, minutes: Int) -> String {
        switch reason {
        case .longerThanCommitment:
            return L(
                "Việc này dài \(durationText(minutes)), hơn thời gian cam kết của mọi ngày. Hãy chia nhỏ nó, hoặc tự tăng cam kết nếu bạn muốn.",
                "This takes \(durationText(minutes)), more than any day's committed time. Break it down, or raise your commitment yourself if you want to."
            )
        case .noRoom:
            return L(
                "Không còn chỗ trong \(Scheduler.horizonDays) ngày tới với cam kết hiện tại. Bạn có thể bỏ bớt việc, đổi thứ tự ưu tiên hoặc lùi hạn.",
                "No room in the next \(Scheduler.horizonDays) days at your current commitment. You could drop something, change priorities or move a deadline."
            )
        }
    }

    // MARK: - Lịch đã duyệt

    private var approvedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !missed.isEmpty {
                Banner(text: L(
                    "\(missed.count) phiên đã trôi qua mà việc chưa xong. Không sao: bấm \"Đề xuất lại lịch\" để xem phương án tiếp tục.",
                    "\(missed.count) planned sessions passed with the work unfinished. That's fine: tap \"Propose again\" to see a way to continue."
                ))
            }

            if !pendingCalendarItems.isEmpty {
                Button {
                    confirmCalendarWrite = true
                } label: {
                    Label(
                        L("Ghi \(pendingCalendarItems.count) thay đổi vào Lịch…", "Write \(pendingCalendarItems.count) changes to Calendar…"),
                        systemImage: "calendar.badge.plus"
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }

            ForEach(days, id: \.day) { group in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(dayText(group.day, weekdayOnly: true).capitalized)
                        .font(Theme.dayTitle)
                        .foregroundStyle(Theme.ink)
                    Text(group.day.formatted(Date.FormatStyle().day().month(.wide).locale(AppLanguage.current.locale)))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 12)

                ForEach(group.items) { item in
                    SessionBlock(item: item, start: item.scheduledStart, note: item.isMissed ? L("Đã lỡ", "Missed") : nil) {
                        startingItem = item
                    }
                }
            }

            if !unscheduled.isEmpty {
                Eyebrow(text: L("Chưa xếp lịch", "Not planned") + " (\(unscheduled.count))")
                    .padding(.top, 12)
                ForEach(unscheduled) { item in
                    SessionBlock(item: item, start: nil, note: nil) {
                        startingItem = item
                    }
                }
            }

            if !scheduled.isEmpty {
                Button(L("Xoá lịch đã duyệt", "Clear approved schedule")) {
                    confirmClear = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }

            if schedulable.isEmpty {
                VStack(spacing: 4) {
                    Text(L("Không có việc để xếp", "Nothing to plan"))
                        .font(Theme.dayTitle)
                        .foregroundStyle(Theme.ink)
                    Text(L("Thêm việc ở tab Công việc hoặc lập kế hoạch ở tab Kế hoạch.", "Add tasks in Tasks or make a plan in Plan."))
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            }
        }
    }

    private var days: [(day: Date, items: [TodoItem])] {
        let groups = Dictionary(grouping: scheduled) {
            Calendar.current.startOfDay(for: $0.scheduledStart ?? .now)
        }
        return groups.keys.sorted().map { (day: $0, items: groups[$0] ?? []) }
    }

    // MARK: - Hành động

    private func propose() {
        let now = Date.now
        var busy: [DateInterval] = []
        if calendarConnected {
            let horizon = now.addingTimeInterval(TimeInterval(Scheduler.horizonDays + 1) * 86400)
            busy = CalendarService.shared.busyIntervals(
                from: now,
                to: horizon,
                excluding: Set(allItems.compactMap(\.calendarEventID))
            )
        }
        let result = Scheduler.plan(tasks: schedulable, busy: busy, from: now)
        proposal = Proposal(
            entries: result.assignments
                .sorted { $0.start < $1.start }
                .map { Entry(item: $0.item, start: $0.start) },
            unscheduled: result.unscheduled
        )
        message = nil
    }

    private func approve() {
        guard let proposal else { return }
        for task in schedulable { task.scheduledStart = nil }
        for entry in proposal.entries { entry.item.scheduledStart = entry.start }
        for task in schedulable { NotificationService.scheduleReminder(for: task) }
        self.proposal = nil
        message = L("Đã duyệt \(proposal.entries.count) phiên.", "Approved \(proposal.entries.count) sessions.")
            + (pendingCalendarItems.isEmpty ? "" : L(" Lịch ngoài chưa thay đổi; bấm nút bên dưới nếu muốn ghi.", " Your outside calendar is unchanged; use the button below to write to it."))
    }

    private func writeToCalendar() {
        for task in pendingCalendarItems { CalendarService.shared.sync(task) }
        message = L("Đã cập nhật ứng dụng Lịch.", "The Calendar app has been updated.")
    }

    private func clearSchedule() {
        for task in allItems where task.scheduledStart != nil {
            task.scheduledStart = nil
            CalendarService.shared.sync(task)
            NotificationService.scheduleReminder(for: task)
        }
        message = nil
    }
}

/// Một phiên trên lịch, tô nền theo màu danh sách.
private struct SessionBlock: View {
    let item: TodoItem
    let start: Date?
    let note: String?
    var showDay = false
    var onStart: (() -> Void)?

    init(item: TodoItem, start: Date?, note: String?, showDay: Bool = false, onStart: (() -> Void)? = nil) {
        self.item = item
        self.start = start
        self.note = note
        self.showDay = showDay
        self.onStart = onStart
    }

    var body: some View {
        let category = item.effectiveCategory
        let end = start?.addingTimeInterval(TimeInterval(max(item.estimatedMinutes, 15) * 60))
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                if let start, let end {
                    Text(timeText(start)).fontWeight(.semibold).foregroundStyle(Theme.ink)
                    Text(timeText(end)).foregroundStyle(Theme.muted)
                }
            }
            .font(.system(size: 13).monospacedDigit())
            .frame(width: 58, alignment: .trailing)
            .padding(.top, 12)

            HStack(alignment: .top, spacing: 8) {
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
                        if let note {
                            TagView(text: note, style: .late)
                        }
                        if showDay, let start {
                            TagView(text: start.formatted(Date.FormatStyle().weekday(.abbreviated).day().month(.defaultDigits).locale(AppLanguage.current.locale)))
                        }
                        if item.effectivePriorityRaw == Priority.high.rawValue {
                            TagView(text: L("Ưu tiên cao", "High priority"), style: .highlight)
                        }
                        TagView(text: category.title, style: .category(category.color))
                        TagView(text: durationText(item.estimatedMinutes))
                        if let due = item.effectiveDueDate {
                            // Đỏ khi giờ kết thúc vượt quá hạn chót.
                            TagView(
                                text: L("Hạn ", "Due ") + shortDateText(due),
                                style: (end ?? .now) > due ? .late : .plain
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let onStart {
                    Button(action: onStart) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 34, height: 34)
                            .background(Theme.card, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Bắt đầu phiên học", "Start a focus session"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(category.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ScheduleView()
        .modelContainer(for: [TodoItem.self, ContextItem.self, FocusSession.self], inMemory: true)
}
