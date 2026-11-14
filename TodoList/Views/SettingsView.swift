import SwiftUI

struct SettingsView: View {
    @AppStorage("workStartHour") private var startHour = 9
    @AppStorage("workEndHour") private var endHour = 18
    @AppStorage("syncCalendar") private var syncCalendar = false

    @State private var apiKey = ""
    @State private var hasSavedKey = KeychainStore.apiKey != nil
    @State private var calendarDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(hasSavedKey ? "Đã lưu khoá (nhập để thay)" : "Khoá API Anthropic", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Lưu khoá") {
                        KeychainStore.setAPIKey(apiKey)
                        apiKey = ""
                        hasSavedKey = KeychainStore.apiKey != nil
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasSavedKey {
                        Button("Xoá khoá", role: .destructive) {
                            KeychainStore.setAPIKey("")
                            hasSavedKey = false
                        }
                    }
                } header: {
                    Text("AI")
                } footer: {
                    Text(
                        "Dùng cho tính năng chia nhỏ công việc và đề xuất ưu tiên (mô hình \(AIService.model)). "
                            + "Khoá được lưu trong Keychain của máy này; nội dung công việc được gửi tới Anthropic khi bạn dùng các tính năng AI."
                    )
                }

                Section {
                    Stepper("Bắt đầu: \(startHour):00", value: $startHour, in: 0...(endHour - 1))
                    Stepper("Kết thúc: \(endHour):00", value: $endHour, in: (startHour + 1)...24)
                } header: {
                    Text("Giờ làm việc")
                } footer: {
                    Text("Bộ xếp lịch chỉ xếp việc trong khung giờ này.")
                }

                Section {
                    Toggle("Đồng bộ với Lịch", isOn: $syncCalendar)
                } header: {
                    Text("Lịch")
                } footer: {
                    Text(
                        calendarDenied
                            ? "Ứng dụng chưa được cấp quyền truy cập Lịch. Hãy bật trong Cài đặt của iPhone → Quyền riêng tư → Lịch."
                            : "Khi bật, bộ xếp lịch tránh các sự kiện bạn đã có và ghi các khối công việc đã xếp vào Lịch."
                    )
                }
            }
            .navigationTitle("Cài đặt")
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
