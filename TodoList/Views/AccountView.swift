import SwiftUI
import SwiftData

struct AccountView: View {
    @ObservedObject private var api = BackendClient.shared
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("backendURL") private var backendURL = "http://localhost:8000"
    @State private var apiKey = ""
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    TextField("https://api.example.com", text: $backendURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    SecureField("OpenAI API key", text: $apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(L("Kết nối bằng key", "Connect with API key")) {
                        busy = true; errorText = nil
                        Task { @MainActor in
                            defer { busy = false }
                            do {
                                try await api.signIn(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                                apiKey = ""
                                await SyncCoordinator.shared.sync(context)
                                dismiss()
                            } catch { errorText = error.localizedDescription }
                        }
                    }.disabled(busy || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text(L("Đăng nhập", "Sign in"))
                } footer: {
                    Text(L("Backend kiểm tra key với OpenAI và lưu mã hóa. Dùng cùng key sẽ dùng chung dữ liệu demo; đổi key tạo danh tính khác. Không cần email hay mã OTP.",
                           "The backend validates your key with OpenAI and stores it encrypted. The same key shares demo data; a different key uses a different identity. No email or OTP."))
                }
                if let errorText { Text(errorText).foregroundStyle(.red) }
                if busy { ProgressView() }
                #if DEBUG
                Section("Local development") {
                    Button("Sign in to localhost (development server only)") {
                        Task { @MainActor in
                            do { try await api.developmentLogin(); await SyncCoordinator.shared.sync(context) }
                            catch { errorText = error.localizedDescription }
                        }
                    }
                }
                #endif
            }
            .navigationTitle("Etsgo")
            .onDisappear { apiKey = "" }
        }
    }
}
