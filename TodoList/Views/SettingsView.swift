import SwiftUI
import SwiftData

/// Chỉnh lịch học mặc định theo tuần: khung giờ có thể xếp và thời gian muốn cam kết mỗi ngày.
struct WeeklyScheduleEditor: View {
    @State private var week = StudySchedule.load()
    /// Thứ hai đến Chủ nhật.
    private let displayOrder = [1, 2, 3, 4, 5, 6, 0]

    var body: some View {
        ForEach(displayOrder, id: \.self) { index in
            Section(StudySchedule.weekdayName(index)) {
                Toggle(L("Có học", "I study this day"), isOn: $week[index].enabled)
                if week[index].enabled {
                    Stepper(
                        L("Từ ", "From ") + "\(week[index].startHour):00",
                        value: $week[index].startHour, in: 0...(week[index].endHour - 1)
                    )
                    Stepper(
                        L("Đến ", "Until ") + "\(week[index].endHour):00",
                        value: $week[index].endHour, in: (week[index].startHour + 1)...24
                    )
                    Stepper(
                        L("Cam kết: ", "Commit: ") + durationText(week[index].commitMinutes),
                        value: $week[index].commitMinutes, in: 15...960, step: 15
                    )
                }
            }
        }
        .onChange(of: week) { _, updated in
            StudySchedule.save(updated)
        }
    }
}

struct WeeklyScheduleScreen: View {
    var body: some View {
        Form {
            Section {
            } footer: {
                Text(L(
                    "Khung giờ là lúc CÓ THỂ học; cam kết là phần bạn muốn dành cho việc học, đã gồm giờ nghỉ. Giờ trống không có nghĩa là giờ học. Bạn xác nhận lại cam kết của từng ngày ở tab Lịch.",
                    "The window is when you COULD study; the commitment is how much you want to give to studying, breaks included. Free time is not study time. You confirm each day's commitment in the Schedule tab."
                ))
            }
            WeeklyScheduleEditor()
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Theme.ink)
        .navigationTitle(L("Lịch học tuần", "Weekly study hours"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct APIKeyFields: View {
    var body: some View {
        Text(L("AI được cấu hình và quản lý hạn mức tại backend.", "AI credentials and usage limits are managed by the backend."))
    }
}

struct SettingsView: View {
    @AppStorage("language") private var language = "vi"
    @AppStorage("syncCalendar") private var syncCalendar = false
    @AppStorage("onboarded") private var onboarded = true
    @State private var calendarDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Ngôn ngữ", "Language")) {
                    Picker(L("Ngôn ngữ", "Language"), selection: $language) {
                        ForEach(AppLanguage.allCases) { Text($0.name).tag($0.rawValue) }
                    }
                }

                Section {
                    NavigationLink(L("Context cá nhân", "Personal context")) { ContextView() }
                    NavigationLink(L("Lịch học tuần", "Weekly study hours")) { WeeklyScheduleScreen() }
                } header: {
                    Text(L("Cá nhân hoá", "Personalisation"))
                } footer: {
                    Text(L(
                        "AI dùng hai nguồn này để đề xuất bước học, độ dài phiên và giờ học hợp với bạn.",
                        "AI uses these to propose steps, session lengths and study times that fit you."
                    ))
                }

                Section {
                    Toggle(L("Kết nối Lịch của iPhone", "Connect iPhone Calendar"), isOn: $syncCalendar)
                } header: {
                    Text(L("Lịch ngoài", "Outside calendar"))
                } footer: {
                    Text(
                        calendarDenied
                            ? L(
                                "Ứng dụng chưa được cấp quyền truy cập Lịch. Hãy bật trong Cài đặt của iPhone → Quyền riêng tư → Lịch.",
                                "The app has no Calendar access. Turn it on in iPhone Settings → Privacy → Calendars."
                            )
                            : L(
                                "Khi bật, đề xuất lịch tránh các sự kiện bạn đã có. Ứng dụng chỉ ghi vào Lịch sau khi bạn duyệt từng lần.",
                                "When on, proposals avoid your existing events. The app writes to Calendar only after you approve each time."
                            )
                    )
                }

                Section {
                    NavigationLink(L("Tài khoản và đồng bộ", "Account and sync")) { BackendSettingsView() }
                } header: {
                    Text("AI")
                } footer: {
                    Text(L(
                        "AI chạy qua backend. Công việc và context đồng bộ theo tài khoản. To-do và Pomodoro dùng được offline.",
                        "AI runs through the backend. Tasks and context sync with your account. Manual tasks and Pomodoro work offline."
                    ))
                }

                Section {
                    Button(L("Xem lại phần thiết lập ban đầu", "Run the setup again")) {
                        onboarded = false
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.ink)
            .navigationTitle(L("Cài đặt", "Settings"))
            .onChange(of: syncCalendar) { _, isOn in
                guard isOn else { return }
                Task { @MainActor in
                    let granted = await CalendarService.shared.requestAccess()
                    calendarDenied = !granted
                    if !granted { syncCalendar = false }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

struct BackendSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @ObservedObject private var sync = SyncCoordinator.shared
    @ObservedObject private var api = BackendClient.shared
    @State private var note = ""
    @State private var calendars: [(id: String, title: String)] = []
    @State private var selected: Set<String> = []
    @State private var confirmLogout = false
    @State private var reauthenticate = false
    var body: some View {
        Form {
            Section(L("Đồng bộ", "Sync")) {
                Button(L("Đăng nhập lại", "Renew sign-in")) { reauthenticate = true }
                Text(sync.status)
                Button(L("Đồng bộ ngay", "Sync now")) { Task { await sync.sync(context) } }
                Button(L("Xem hạn mức AI", "Check AI usage")) {
                    Task { @MainActor in
                        do { let value = try await api.request("GET", "/v1/usage"); note = "\(value["used"] ?? 0) / \(value["limit"] ?? 0)" }
                        catch { note = error.localizedDescription }
                    }
                }
                if sync.hasConflicts {
                    Text(L("Có thay đổi xung đột. Chọn bản giữ lại; dữ liệu đã xóa trên server không được tự phục hồi.", "Conflicting edits need review. Server-deleted records cannot be restored implicitly."))
                    Button(L("Giữ các sửa local", "Keep local edits")) { resolve(true) }
                    Button(L("Dùng bản server", "Use server versions")) { resolve(false) }
                }
            }
            Section("Google Calendar") {
                Button(L("Kết nối Google Calendar", "Connect Google Calendar")) {
                    Task { @MainActor in
                        do {
                            let result = try await api.request("POST", "/v1/calendar/google/connect")
                            if let text = result["url"] as? String, let url = URL(string: text) { openURL(url) }
                        } catch { note = error.localizedDescription }
                    }
                }
            }
            Section(L("Nguồn đọc EventKit", "EventKit read sources")) {
                Text(L("Nếu Google đã kết nối trực tiếp, bỏ chọn các lịch Google trùng ở đây.", "When Google is connected directly, deselect the same Google calendars here."))
                Button(L("Tải danh sách lịch", "Load calendars")) {
                    Task { @MainActor in
                        if await CalendarService.shared.requestAccess() {
                            calendars = CalendarService.shared.calendars()
                            selected = Set(UserDefaults.standard.stringArray(forKey: "eventkitReadCalendars") ?? calendars.map(\.id))
                        }
                    }
                }
                ForEach(calendars, id: \.id) { calendar in
                    Toggle(calendar.title, isOn: Binding(get: { selected.contains(calendar.id) }, set: {
                        if $0 { selected.insert(calendar.id) } else { selected.remove(calendar.id) }
                        UserDefaults.standard.set(Array(selected), forKey: "eventkitReadCalendars")
                    }))
                }
                Button(L("Lưu nguồn đã chọn", "Save selected sources")) {
                    UserDefaults.standard.set(Array(selected), forKey: "eventkitReadCalendars")
                }
            }
            if !note.isEmpty { Text(note) }
            Section {
                Button(L("Đăng xuất và xóa bản local", "Sign out and clear local cache"), role: .destructive) { confirmLogout = true }
            }
        }
        .navigationTitle(L("Tài khoản", "Account"))
        .sheet(isPresented: $reauthenticate) { AccountView() }
        .confirmationDialog(L("Đồng bộ rồi đăng xuất?", "Sync and sign out?"), isPresented: $confirmLogout) {
            Button(L("Xác nhận", "Confirm"), role: .destructive) { logout() }
        }
    }
    private func resolve(_ keep: Bool) {
        do { try sync.resolve(context, keepLocal: keep); Task { await sync.sync(context) } }
        catch { note = error.localizedDescription }
    }
    private func logout() {
        Task { @MainActor in
            await sync.sync(context)
            do {
                try sync.capture(context)
                guard try context.fetch(FetchDescriptor<PendingOperation>()).isEmpty else {
                    note = L("Còn thay đổi chưa đồng bộ. Hãy đồng bộ hoặc giải quyết xung đột trước.", "Unsynced edits remain. Sync or resolve conflicts first."); return
                }
                api.signOut()
                for item in try context.fetch(FetchDescriptor<TodoItem>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<ContextItem>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<FocusSession>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<PlannedSession>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<SyncRecord>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<PendingOperation>()) { context.delete(item) }
                try context.save()
                for key in UserDefaults.standard.dictionaryRepresentation().keys where
                    key.hasPrefix("sync") || key.hasPrefix("commit-") || key.hasPrefix("planner") ||
                    ["localOwner", "weeklySchedule", "activePomodoro", "eventkitReadCalendars", "eventkitOutputCalendar"].contains(key) {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            } catch { note = error.localizedDescription }
        }
    }
}
