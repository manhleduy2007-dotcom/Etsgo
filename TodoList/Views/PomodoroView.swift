import SwiftUI
import SwiftData

/// Phiên tập trung cho một việc: hướng dẫn ngắn, bộ đếm tập trung / nghỉ, cập nhật sau phiên.
/// Hết giờ KHÔNG tự đánh dấu việc đã xong (PO-03).
struct PomodoroView: View {
    private enum Phase {
        case setup, focus, rest, feedback, stuck
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var contextItems: [ContextItem]
    @Bindable var item: TodoItem

    @State private var phase: Phase = .setup
    @State private var total: TimeInterval = 0
    @State private var remaining: TimeInterval = 0
    @State private var endDate: Date?
    @State private var paused = false
    @State private var lastFocusSeconds = 0
    @State private var runID = UUID().uuidString.lowercased()
    @State private var actualStart = Date.now
    @State private var lastSessionID: String?

    @State private var loadingGuidance = false
    @State private var guidanceNote: String?
    @State private var extraMinutes = 25
    @State private var problem = ""
    @State private var advice: UnblockAdvice?
    @State private var busy = false
    @State private var errorText: String?

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let notificationID = "pomodoro-phase"

    private var color: Color { item.effectiveCategory.color }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow(text: phaseName)
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                        .background(Theme.card, in: Circle())
                }
                .accessibilityLabel(L("Đóng", "Close"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        if let parent = item.parent {
                            Text(parent.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    switch phase {
                    case .setup: setupView
                    case .focus, .rest: timerView
                    case .feedback: feedbackView
                    case .stuck: stuckView
                    }

                    if let errorText {
                        Banner(text: errorText)
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onReceive(ticker) { _ in tick() }
        .interactiveDismissDisabled()
        .onChange(of: scenePhase) { _, phase in if phase != .active { persist() } }
        .task {
            restore()
            await SyncCoordinator.shared.sync(context)
            if item.guidanceTip.isEmpty { await loadGuidance(excluding: "") }
        }
    }

    private var phaseName: String {
        switch phase {
        case .setup: return L("Chuẩn bị", "Get ready")
        case .focus: return paused ? L("Tạm dừng", "Paused") : L("Đang tập trung", "Focusing")
        case .rest: return L("Nghỉ", "Break")
        case .feedback: return L("Sau phiên", "After the session")
        case .stuck: return L("Đang vướng", "Stuck")
        }
    }

    // MARK: - Chuẩn bị: hướng dẫn đúng lúc và độ dài phiên

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: L("Để bắt đầu", "To get started"))
                if loadingGuidance {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L("AI đang chuẩn bị hướng dẫn ngắn…", "AI is preparing a short pointer…"))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }
                } else if !item.guidanceTip.isEmpty {
                    Text(item.guidanceTip)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink)
                    if !item.resourceTitle.isEmpty, let url = searchURL {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.resourceTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(L(
                                "Gợi ý của AI, chưa được kiểm chứng. Nút dưới mở trang tìm kiếm, không phải một nguồn đã xác nhận.",
                                "AI suggestion, not verified. The button opens a web search, not a confirmed source."
                            ))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            HStack(spacing: 16) {
                                Link(L("Tìm tài liệu này", "Search for this"), destination: url)
                                Button(L("Đổi tài liệu", "Suggest another")) {
                                    Task { await loadGuidance(excluding: item.resourceTitle) }
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .tint(color)
                        }
                    }
                } else {
                    Text(guidanceNote ?? L("Chưa có hướng dẫn cho việc này.", "No pointer for this step yet."))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                    Button(L("Lấy hướng dẫn ngắn", "Get a short pointer")) {
                        Task { await loadGuidance(excluding: "") }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .tint(color)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))

            VStack(spacing: 0) {
                Stepper(
                    L("Tập trung: ", "Focus: ") + durationText(item.focusMinutes),
                    value: $item.focusMinutes, in: 5...90, step: 5
                )
                .padding(14)
                Divider()
                Stepper(L("Nghỉ: ", "Break: ") + durationText(item.breakMinutes), value: $item.breakMinutes, in: 1...30)
                    .padding(14)
            }
            .foregroundStyle(Theme.ink)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))

            Text(L(
                "Việc này ước tính \(durationText(item.estimatedMinutes)). Một việc có thể cần nhiều phiên.",
                "This step is estimated at \(durationText(item.estimatedMinutes)). A step may take several sessions."
            ))
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)

            Button {
                start(.focus)
            } label: {
                PrimaryLabel(title: L("Bắt đầu tập trung", "Start focusing"), systemImage: "play.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var searchURL: URL? {
        let query = item.resourceQuery.isEmpty ? item.resourceTitle : item.resourceQuery
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    // MARK: - Bộ đếm

    private var timerView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: total > 0 ? remaining / total : 0)
                    .stroke(phase == .focus ? color : Theme.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(clock(remaining))
                    .font(.system(size: 56, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 240, height: 240)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            HStack(spacing: 12) {
                Button {
                    paused ? resume() : pause()
                } label: {
                    Label(
                        paused ? L("Tiếp tục", "Resume") : L("Tạm dừng", "Pause"),
                        systemImage: paused ? "play.fill" : "pause.fill"
                    )
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                    phase == .focus ? finishFocus() : backToSetup()
                } label: {
                    PrimaryLabel(title: phase == .focus ? L("Kết thúc sớm", "End early") : L("Bỏ qua nghỉ", "Skip break"))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    // MARK: - Cập nhật sau phiên

    private var feedbackView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(
                "Bạn vừa tập trung \(durationText(max(lastFocusSeconds / 60, 1))). Việc này thế nào rồi?",
                "You just focused for \(durationText(max(lastFocusSeconds / 60, 1))). Where does this step stand?"
            ))
            .font(.system(size: 15))
            .foregroundStyle(Theme.ink)

            Button {
                setOutcome("done")
                context.setDone(item, true)
                close()
            } label: {
                PrimaryLabel(title: L("Xong", "Done"), systemImage: "checkmark")
            }
            .buttonStyle(.plain)

            choice(L("Nghỉ \(durationText(item.breakMinutes)) rồi làm tiếp", "Take a \(durationText(item.breakMinutes)) break, then continue"), "cup.and.saucer.fill") {
                start(.rest)
            }

            VStack(spacing: 0) {
                Stepper(
                    L("Cần thêm: ", "Need more: ") + durationText(extraMinutes),
                    value: $extraMinutes, in: 15...240, step: 15
                )
                .foregroundStyle(Theme.ink)
                .padding(14)
                Divider()
                Button {
                    setOutcome("more_time")
                    // Tăng ước lượng và bỏ giờ đã xếp: lịch mới sẽ được đề xuất để người dùng duyệt ở tab Lịch.
                    item.estimatedMinutes = extraMinutes
                    item.scheduledStart = nil
                    close()
                } label: {
                    Label(L("Cần thêm thời gian", "I need more time"), systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .buttonStyle(.plain)
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))

            choice(L("Đang vướng", "I'm stuck"), "questionmark.circle.fill") {
                setOutcome("stuck")
                item.isStuck = true
                phase = .stuck
            }

            Text(L(
                "Khi chọn cần thêm thời gian, phần còn lại sẽ nằm ở mục chưa xếp trong tab Lịch để bạn duyệt lịch mới.",
                "If you need more time, the remainder shows up as unplanned in the Schedule tab for you to approve a new slot."
            ))
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
        }
    }

    private func choice(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Đang vướng: AI đề xuất cách tiếp tục, người dùng duyệt

    private var stuckView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let advice {
                Text(advice.message)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                if !advice.steps.isEmpty {
                    Eyebrow(text: L("Bước đề xuất thêm", "Suggested extra steps"))
                    ForEach(Array(advice.steps.enumerated()), id: \.offset) { _, step in
                        HStack {
                            Text(step.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            TagView(text: durationText(step.estimatedMinutes))
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    }
                    Button {
                        item.insertFollowUpSteps(advice.steps.map {
                            (title: $0.title, minutes: min(max($0.estimatedMinutes, 15), 480))
                        })
                        close()
                    } label: {
                        PrimaryLabel(title: L("Thêm các bước này", "Add these steps"), systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                }
                choice(L("Không thêm, đóng lại", "Don't add, close"), "xmark") { close() }
            } else {
                Text(L(
                    "Bạn vướng ở đâu? Mô tả ngắn (hoặc để trống), AI sẽ đề xuất cách đi tiếp để bạn xem trước.",
                    "Where are you stuck? Describe it briefly (or leave it blank) and AI will suggest a way forward for you to review."
                ))
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)

                HStack(alignment: .top, spacing: 4) {
                    TextField(L("Ví dụ: chưa hiểu vòng lặp for", "e.g. I don't get for loops"), text: $problem, axis: .vertical)
                        .lineLimit(2...5)
                        .foregroundStyle(Theme.ink)
                    MicButton(text: $problem)
                }
                .padding(.leading, 14)
                .padding(.vertical, 6)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))

                Button {
                    askForHelp()
                } label: {
                    if busy {
                        ProgressView().frame(maxWidth: .infinity).frame(height: 48)
                    } else {
                        PrimaryLabel(title: L("Đề xuất cách đi tiếp", "Suggest a way forward"), systemImage: "sparkles")
                    }
                }
                .buttonStyle(.plain)
                .disabled(busy)

                choice(L("Để sau", "Later"), "xmark") { close() }
            }
        }
    }

    // MARK: - Điều khiển phiên

    private func start(_ next: Phase) {
        errorText = nil
        total = TimeInterval((next == .focus ? item.focusMinutes : item.breakMinutes) * 60)
        remaining = total
        paused = false
        phase = next
        endDate = Date.now.addingTimeInterval(total)
        if next == .focus { runID = UUID().uuidString.lowercased(); actualStart = .now }
        persist()
        scheduleEndNotification()
        if next == .focus {
            Task { _ = await NotificationService.requestAccess() }
        }
    }

    private func scheduleEndNotification() {
        NotificationService.cancel(notificationID)
        guard let endDate else { return }
        NotificationService.schedule(
            id: notificationID,
            title: phase == .focus ? L("Hết phiên tập trung", "Focus session finished") : L("Hết giờ nghỉ", "Break is over"),
            body: item.title,
            at: endDate
        )
    }

    private func pause() {
        if let endDate { remaining = max(0, endDate.timeIntervalSinceNow) }
        paused = true
        endDate = nil
        NotificationService.cancel(notificationID)
        persist()
    }

    private func resume() {
        paused = false
        endDate = Date.now.addingTimeInterval(remaining)
        scheduleEndNotification()
        persist()
    }

    /// Dùng mốc kết thúc thay vì đếm từng giây, nên bộ đếm vẫn đúng sau khi app ở nền.
    private func tick() {
        guard phase == .focus || phase == .rest, !paused, let endDate else { return }
        remaining = max(endDate.timeIntervalSinceNow, 0)
        persist()
        guard remaining == 0 else { return }
        if phase == .focus {
            finishFocus()
        } else {
            backToSetup()
        }
    }

    private func finishFocus() {
        NotificationService.cancel(notificationID)
        if !paused, let endDate { remaining = max(0, endDate.timeIntervalSinceNow) }
        let seconds = Int(total - remaining)
        lastFocusSeconds = seconds
        recordFocus(seconds)
        endDate = nil
        extraMinutes = 25
        phase = .feedback
        UserDefaults.standard.removeObject(forKey: "activePomodoro")
    }

    private func backToSetup() {
        NotificationService.cancel(notificationID)
        endDate = nil
        phase = .setup
        UserDefaults.standard.removeObject(forKey: "activePomodoro")
    }

    private func close() {
        if phase == .focus {
            // Đóng giữa phiên vẫn ghi lại thời gian đã tập trung.
            if !paused, let endDate { remaining = max(0, endDate.timeIntervalSinceNow) }
            let seconds = Int(total - remaining)
            if seconds > 0 {
                recordFocus(seconds)
            }
        }
        UserDefaults.standard.removeObject(forKey: "activePomodoro")
        try? context.save()
        try? SyncCoordinator.shared.capture(context)
        NotificationService.cancel(notificationID)
        dismiss()
    }

    private func recordFocus(_ seconds: Int) {
        let sessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
        if !sessions.contains(where: { $0.uid == runID }) {
            let session = FocusSession(taskTitle: item.title, focusSeconds: max(0, seconds))
            session.uid = runID; session.taskID = item.uid
            session.startedAt = actualStart; session.finishedAt = .now
            context.insert(session)
            item.spentSeconds += max(0, seconds)
        }
        lastSessionID = runID
        try? context.save()
    }

    private func setOutcome(_ outcome: String) {
        guard let id = lastSessionID else { return }
        let sessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
        sessions.first { $0.uid == id }?.outcomeRaw = outcome
        try? context.save()
    }

    private func persist() {
        guard phase == .focus || phase == .rest else { return }
        let value: [String: Any] = ["task_id": item.uid, "run_id": runID, "owner": BackendClient.shared.userID ?? "",
            "phase": phase == .focus ? "focus" : "rest", "total": total, "remaining": remaining,
            "paused": paused, "end": endDate?.timeIntervalSince1970 ?? 0, "start": actualStart.timeIntervalSince1970]
        UserDefaults.standard.set(try? JSONSerialization.data(withJSONObject: value), forKey: "activePomodoro")
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: "activePomodoro"),
              let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              value["task_id"] as? String == item.uid,
              value["owner"] as? String == BackendClient.shared.userID else { return }
        runID = value["run_id"] as? String ?? UUID().uuidString.lowercased()
        total = value["total"] as? Double ?? 1500
        remaining = value["remaining"] as? Double ?? total
        paused = value["paused"] as? Bool ?? false
        actualStart = Date(timeIntervalSince1970: value["start"] as? Double ?? Date.now.timeIntervalSince1970)
        let end = value["end"] as? Double ?? 0
        endDate = end > 0 ? Date(timeIntervalSince1970: end) : nil
        phase = value["phase"] as? String == "rest" ? .rest : .focus
        tick()
    }

    // MARK: - AI

    private func loadGuidance(excluding: String) async {
        guard !loadingGuidance else { return }
        loadingGuidance = true
        defer { loadingGuidance = false }
        do {
            let result = try await AIService().guidance(
                task: item.title,
                goal: item.parent?.title ?? "",
                context: buildPromptContext(contextItems),
                excluding: excluding,
                taskID: item.uid
            )
            item.guidanceTip = result.tip
            item.resourceTitle = result.resourceTitle
            item.resourceQuery = result.searchQuery
            guidanceNote = nil
        } catch {
            guidanceNote = error.localizedDescription
        }
    }

    private func askForHelp() {
        busy = true
        errorText = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                advice = try await AIService().unblock(
                    task: item.title,
                    goal: item.parent?.title ?? "",
                    problem: problem,
                    context: buildPromptContext(contextItems),
                    taskID: item.uid
                )
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
