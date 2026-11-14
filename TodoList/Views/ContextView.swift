import SwiftUI
import SwiftData
import UIKit

/// Prompt handoff để người dùng mang sang AI họ đang dùng (đặc tả mục 7).
enum HandoffPrompt {
    static var text: String {
        L(
            """
            Tôi muốn chuyển context liên quan đến việc học của mình sang một ứng dụng lập kế hoạch học tập. Dựa trên thông tin bạn thực sự có thể truy cập trong cuộc trò chuyện/context hiện tại, hãy tạo bản tóm tắt ngắn bằng ngôn ngữ tôi đang dùng.

            Chỉ tổng hợp thông tin có liên quan: mục tiêu đang học, kiến thức/nền tảng hiện có, sở thích học, những chỗ đang vướng, thời gian hoặc lịch sinh hoạt tôi đã đề cập và các giới hạn tôi đã nói rõ.

            Phân biệt thông tin tôi đã nói với suy đoán của bạn. Chỗ chưa biết hãy ghi “chưa biết”; không tự bịa hoặc hỏi thêm chỉ để điền đủ. Nếu có thông tin mâu thuẫn hoặc có thể đã cũ, hãy đánh dấu. Không đưa thông tin nhạy cảm không cần thiết cho việc học. Tôi sẽ xem lại bản tóm tắt trước khi chuyển sang ứng dụng.
            """,
            """
            I want to move the context about my learning into a study-planning app. Based only on information you can actually access in this conversation/context, write a short summary in the language I am using.

            Include only what is relevant: what I am currently learning, my existing knowledge/background, how I like to study, where I am stuck, the time or daily routine I have mentioned, and any limits I stated clearly.

            Separate what I told you from what you are guessing. Where you don't know, write "unknown"; do not make things up or ask more questions just to fill gaps. Flag anything contradictory or possibly outdated. Leave out sensitive details that are not needed for studying. I will review the summary before moving it to the app.
            """
        )
    }
}

/// Sao chép prompt, dán kết quả về, AI tổng hợp thành các mẩu context chưa xác nhận (CT-01).
struct HandoffImportView: View {
    @Environment(\.modelContext) private var context
    @State private var pasted = ""
    @State private var busy = false
    @State private var copied = false
    @State private var status: String?

    var body: some View {
        Section {
            Text(HandoffPrompt.text)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .textSelection(.enabled)
            Button {
                UIPasteboard.general.string = HandoffPrompt.text
                copied = true
            } label: {
                Label(copied ? L("Đã sao chép", "Copied") : L("Sao chép prompt", "Copy the prompt"), systemImage: "doc.on.doc")
            }
        } header: {
            Text(L("1. Gửi prompt này cho AI bạn đang dùng", "1. Send this prompt to the AI you already use"))
        }

        Section {
            TextField(L("Dán câu trả lời của AI kia vào đây", "Paste the other AI's answer here"), text: $pasted, axis: .vertical)
                .lineLimit(4...10)
            Button {
                importHandoff()
            } label: {
                if busy {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L("Đang tổng hợp…", "Summarising…"))
                    }
                } else {
                    Label(L("Tổng hợp thành context", "Turn into context"), systemImage: "sparkles")
                }
            }
            .disabled(busy || pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let status {
                Text(status).font(.footnote).foregroundStyle(Theme.muted)
            }
        } header: {
            Text(L("2. Mang kết quả về", "2. Bring the result back"))
        } footer: {
            Text(L(
                "Thông tin nhập vào được đánh dấu chưa xác nhận. Bạn xem, sửa, xác nhận hoặc xoá từng mục; ứng dụng không truy cập lịch sử trò chuyện của bạn ở dịch vụ khác.",
                "Imported information is marked unconfirmed. You review, edit, confirm or delete each item; the app does not access your chat history in other services."
            ))
        }
    }

    private func importHandoff() {
        let text = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        status = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                let drafts = try await AIService().summarizeHandoff(text: text)
                for draft in drafts where !draft.text.isEmpty {
                    // Kể cả điều AI kia nói là người dùng đã phát biểu cũng chỉ là thông tin nhập, chưa phải xác nhận hiện tại.
                    context.insert(ContextItem(text: draft.text, source: draft.stated ? "handoff" : "assumption", confirmed: false))
                }
                pasted = ""
                status = L("Đã thêm \(drafts.count) mục, chờ bạn xem lại.", "Added \(drafts.count) items for you to review.")
            } catch {
                // Không gọi được AI thì vẫn giữ nguyên văn để người dùng tự sửa.
                context.insert(ContextItem(text: text, source: "handoff", confirmed: false))
                pasted = ""
                status = error.localizedDescription
                    + L(" Đã lưu nguyên văn thành một mục chưa xác nhận.", " The text was saved as-is as one unconfirmed item.")
            }
        }
    }
}

/// Context cá nhân: người dùng thấy ứng dụng đang lưu gì, và sửa hoặc xoá được (CT-02).
struct ContextView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ContextItem.createdAt) private var items: [ContextItem]
    @State private var newText = ""

    var body: some View {
        Form {
            Section {
                ForEach(items) { item in
                    ContextRow(item: item)
                }
                .onDelete { offsets in
                    offsets.map { items[$0] }.forEach { context.delete($0) }
                }
                TextField(L("Thêm điều bạn muốn AI biết…", "Add something you want the AI to know…"), text: $newText, axis: .vertical)
                    .onSubmit(addOwn)
                Button(L("Thêm", "Add"), action: addOwn)
                    .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text(L("Điều ứng dụng biết về bạn", "What the app knows about you"))
            } footer: {
                Text(L(
                    "Ví dụ: \"Mình chưa biết lập trình\", \"Mình thích phiên 25 phút\", \"Buổi tối mình học tốt hơn\". Điều bạn xác nhận được ưu tiên hơn thông tin nhập từ AI khác. Vuốt để xoá.",
                    "For example: \"I've never programmed\", \"I like 25-minute sessions\", \"I study better in the evening\". What you confirm outranks anything imported from another AI. Swipe to delete."
                ))
            }

            HandoffImportView()
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Theme.ink)
        .navigationTitle(L("Context cá nhân", "Personal context"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addOwn() {
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        context.insert(ContextItem(text: text, source: "user", confirmed: true))
        newText = ""
    }
}

private struct ContextRow: View {
    @Bindable var item: ContextItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(L("Nội dung", "Text"), text: $item.text, axis: .vertical)
            HStack {
                Text(item.sourceLabel)
                    .font(.caption)
                    .foregroundStyle(item.confirmed ? Theme.green : Theme.muted)
                Spacer()
                if !item.confirmed {
                    Button(L("Đúng, xác nhận", "Correct, confirm")) {
                        item.confirmed = true
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}
