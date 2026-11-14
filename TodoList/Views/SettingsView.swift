import SwiftUI

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
    @State private var apiKey = ""
    @State private var hasSavedKey = KeychainStore.apiKey != nil

    var body: some View {
        SecureField(
            hasSavedKey ? L("Đã lưu khoá (nhập để thay)", "Key saved (type to replace)") : L("Khoá API Anthropic", "Anthropic API key"),
            text: $apiKey
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        Button(L("Lưu khoá", "Save key")) {
            KeychainStore.setAPIKey(apiKey)
            apiKey = ""
            hasSavedKey = KeychainStore.apiKey != nil
        }
        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if hasSavedKey {
            Button(L("Xoá khoá", "Remove key"), role: .destructive) {
                KeychainStore.setAPIKey("")
                hasSavedKey = false
            }
        }
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
                    APIKeyFields()
                } header: {
                    Text("AI")
                } footer: {
                    Text(L(
                        "Bản thử nghiệm gọi thẳng Claude (\(AIService.model)) bằng khoá của bạn, lưu trong Keychain của máy. Nội dung công việc và context được gửi tới Anthropic khi bạn dùng tính năng AI. Tạo việc thủ công không cần AI.",
                        "This test build calls Claude (\(AIService.model)) directly with your key, stored in this device's Keychain. Task content and context are sent to Anthropic when you use AI features. Adding tasks by hand needs no AI."
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
