import SwiftUI
import SwiftData

struct AccountView: View {
    @ObservedObject private var api = BackendClient.shared
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("backendURL") private var backendURL = "http://localhost:8000"
    @State private var email = ""
    @State private var code = ""
    @State private var sent = false
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    TextField("https://api.example.com", text: $backendURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section(L("Đăng nhập", "Sign in")) {
                    TextField("Email", text: $email).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if sent { TextField(L("Mã OTP", "OTP code"), text: $code).keyboardType(.numberPad) }
                    Button(sent ? L("Xác nhận và nhập dữ liệu local", "Verify and import local data") : L("Gửi mã", "Send code")) {
                        busy = true; errorText = nil
                        Task { @MainActor in
                            defer { busy = false }
                            do {
                                if sent {
                                    try await api.verify(email: email, code: code)
                                    await SyncCoordinator.shared.sync(context)
                                    dismiss()
                                } else { try await api.sendCode(email: email); sent = true }
                            } catch { errorText = error.localizedDescription }
                        }
                    }.disabled(busy || email.isEmpty || (sent && code.isEmpty))
                } footer: {
                    Text(L("Khi xác nhận, công việc và context trên máy sẽ được đồng bộ vào tài khoản này. AI cần kết nối mạng.",
                           "Verifying will synchronize local tasks and context into this account. AI needs a network connection."))
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
        }
    }
}
