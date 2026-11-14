import SwiftUI
import SwiftData

/// Server proposals are kept separate from approved planned sessions.
struct ScheduleView: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TodoItem]
    @Query(sort: \PlannedSession.start) private var sessions: [PlannedSession]
    @State private var proposal: [String: Any]?
    @State private var entries: [[String: Any]] = []
    @State private var busy = false
    @State private var message: String?
    @State private var todayCommit = StudySchedule.commitment(for: .now)
    @State private var startingItem: TodoItem?
    @State private var confirmExport = false
    @State private var exportTarget = "eventkit"
    private var api: BackendClient { BackendClient.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("Lịch", "Schedule")).font(Theme.display)
                Stepper(L("Hôm nay cam kết: ", "Today I commit: ")+durationText(todayCommit),
                    value: $todayCommit, in: 0...1440, step: 15)
                    .onChange(of: todayCommit) { _, value in StudySchedule.setCommitment(value, for: .now) }
                Text(L("Thời gian cam kết gồm cả giờ nghỉ.", "Commitment includes breaks.")).font(.caption)
                Button { propose() } label: { PrimaryLabel(title: L("Đề xuất lịch học", "Propose a schedule")) }
                    .disabled(busy)
                if busy { ProgressView() }
                if let message { Banner(text: message) }
                if let proposal {
                    Eyebrow(text: L("Đề xuất, chưa áp dụng", "Proposal, not applied"))
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            block(entry)
                            Button { entries.remove(at: index) } label: { Image(systemName: "xmark") }
                        }
                    }
                    ForEach(proposal["warnings"] as? [String] ?? [], id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                    ForEach(Array((proposal["unscheduled"] as? [[String: Any]] ?? []).enumerated()), id: \.offset) { _, entry in
                        Text(title(entry["task_id"] as? String ?? "")+": "+(entry["reason"] as? String ?? ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button { approve() } label: { PrimaryLabel(title: L("Duyệt lịch này", "Approve schedule")) }
                        .disabled(busy || entries.isEmpty)
                    Button(L("Bỏ đề xuất", "Discard proposal")) { self.proposal = nil }
                } else {
                    ForEach(sessions.filter { session in tasks.contains { $0.uid == session.taskID && !$0.isDone } }) { session in
                        Button {
                            if let task = tasks.first(where: { $0.uid == session.taskID }) {
                                task.focusMinutes = session.focusMinutes; task.breakMinutes = session.breakMinutes
                                startingItem = task
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title(session.taskID)).font(.headline)
                                Text(shortDateText(session.start)+" ? "+timeText(session.end)).font(.caption)
                                Text(durationText(session.focusMinutes)+" / "+durationText(session.breakMinutes)).font(.caption)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                    Picker(L("Ghi vào", "Export to"), selection: $exportTarget) {
                        Text("iPhone Calendar").tag("eventkit")
                        Text("Google Calendar").tag("google")
                    }
                    Button(L("Ghi các phiên đã duyệt vào Lịch…", "Export approved sessions?")) { confirmExport = true }
                        .disabled(busy || sessions.isEmpty)
                }
            }.padding(20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .fullScreenCover(item: $startingItem) { PomodoroView(item: $0) }
        .confirmationDialog(L("Ghi các phiên và xóa phiên Etsgo cũ không còn dùng ở lịch đã chọn?", "Write sessions and remove obsolete Etsgo slots in the selected calendar?"), isPresented: $confirmExport) {
            Button(L("Xác nhận ghi", "Confirm export")) { export() }
            Button(L("Hủy", "Cancel"), role: .cancel) {}
        }
        .task { await SyncCoordinator.shared.sync(context) }
    }
    private func title(_ id: String) -> String { tasks.first { $0.uid == id }?.title ?? id }
    private func block(_ entry: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title(entry["task_id"] as? String ?? "")).font(.headline)
            if let start = SyncCoordinator.shared.date(entry["start"]), let end = SyncCoordinator.shared.date(entry["end"]) {
                Text(shortDateText(start)+" ? "+timeText(end)).font(.caption)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
    private func propose() {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                try await SyncCoordinator.shared.flush(context)
                if UserDefaults.standard.bool(forKey: "syncCalendar") { try await CalendarService.shared.publishBusy() }
                let value = try await api.request("POST", "/v1/schedule/proposals", key: UUID().uuidString.lowercased())
                proposal = value; entries = value["sessions"] as? [[String: Any]] ?? []
                message = nil
            } catch { message = error.localizedDescription }
        }
    }
    private func approve() {
        guard let proposal, let id = proposal["id"] as? String else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                if UserDefaults.standard.bool(forKey: "syncCalendar") { try await CalendarService.shared.publishBusy() }
                let edited = try await api.request("PATCH", "/v1/proposals/"+id,
                    ["expected_version": proposal["version"] as? Int ?? 1, "sessions": entries])
                self.proposal = edited
                _ = try await api.request("POST", "/v1/proposals/"+id+"/accept",
                    ["expected_version": edited["version"] as? Int ?? 1], key: "schedule-accept-"+id)
                self.proposal = nil
                await SyncCoordinator.shared.sync(context)
                message = L("Đã duyệt. Lịch ngoài chưa thay đổi.", "Approved. External calendars are unchanged.")
            } catch { message = error.localizedDescription }
        }
    }
    private func export() {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                let references = sessions.filter { $0.end > .now }.map { ["id": $0.uid, "version": $0.version] as [String: Any] }
                _ = try await api.request("POST", "/v1/calendar/exports",
                    ["target": exportTarget, "device_id": api.deviceID, "sessions": references], key: UUID().uuidString.lowercased())
                if exportTarget == "eventkit" { try await CalendarService.shared.executeActions() }
                message = L("Đã gửi yêu cầu ghi lịch. Google được xử lý bởi worker.", "Calendar export submitted. Google exports run on the worker.")
            } catch { message = error.localizedDescription }
        }
    }
}
