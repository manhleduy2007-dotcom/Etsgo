import SwiftUI

/// Thiết lập ban đầu: ngôn ngữ, context handoff, lịch học tuần. Mọi bước đều bỏ qua được;
/// người dùng nhận được đề xuất đầu tiên mà không cần hoàn tất mọi nguồn dữ liệu (mục 4.1).
struct OnboardingView: View {
    @AppStorage("language") private var language = "vi"
    @State private var step = 0
    var onFinish: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case 0:
                    Section {
                        Picker(L("Ngôn ngữ", "Language"), selection: $language) {
                            ForEach(AppLanguage.allCases) { Text($0.name).tag($0.rawValue) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("Ngôn ngữ / Language")
                    }
                    Section {
                        APIKeyFields()
                    } header: {
                        Text("AI")
                    } footer: {
                        Text(L(
                            "Bản thử nghiệm cần khoá API Anthropic để dùng tính năng AI. Có thể thêm sau trong Cài đặt.",
                            "This test build needs an Anthropic API key for AI features. You can add it later in Settings."
                        ))
                    }
                case 1:
                    Section {
                    } footer: {
                        Text(L(
                            "Để kế hoạch hợp với bạn, hãy mang những gì AI bạn đang dùng đã biết về việc học của bạn sang đây. Không bắt buộc; bạn có thể làm sau.",
                            "For plans that fit you, bring over what the AI you already use knows about your learning. Optional; you can do it later."
                        ))
                    }
                    HandoffImportView()
                default:
                    Section {
                    } footer: {
                        Text(L(
                            "Bạn thường học lúc nào, và muốn dành bao lâu mỗi ngày? Đây là mặc định; mỗi ngày bạn xác nhận lại nhanh ở tab Lịch.",
                            "When do you usually study, and how long do you want to give it each day? This is a default; you confirm quickly each day in the Schedule tab."
                        ))
                    }
                    WeeklyScheduleEditor()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.ink)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Bỏ qua", "Skip"), action: onFinish)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(step < 2 ? L("Tiếp", "Next") : L("Xong", "Done")) {
                        if step < 2 { step += 1 } else { onFinish() }
                    }
                }
            }
        }
        // Dựng lại khi đổi ngôn ngữ ở bước đầu.
        .id(language)
    }

    private var title: String {
        switch step {
        case 0: return L("Chào bạn", "Welcome")
        case 1: return L("Context của bạn", "Your context")
        default: return L("Lịch học tuần", "Weekly study hours")
        }
    }
}
