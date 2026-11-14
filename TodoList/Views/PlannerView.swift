import SwiftUI
import SwiftData

/// Hội thoại lập kế hoạch học: người dùng nói mong muốn, AI hỏi vừa đủ rồi đề xuất kế hoạch để duyệt.
struct PlannerView: View {
    private struct Bubble: Identifiable {
        let id = UUID()
        let fromUser: Bool
        let text: String
        var quickReplies: [String] = []
    }

    private struct DraftStep: Identifiable {
        let id = UUID()
        var title: String
        var minutes: Int
        var focus: Int
        var rest: Int
    }

    private struct Draft {
        var title: String
        var steps: [DraftStep]
        var later: [String]
        var basedOn: [String]
        var assumptions: [String]
    }

    @Environment(\.modelContext) private var context
    @Query private var contextItems: [ContextItem]

    @State private var bubbles: [Bubble] = []
    @State private var history: [ChatMessage] = []
    @State private var draft: Draft?
    @State private var input = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var notice: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: L("Nói điều bạn muốn học", "Say what you want to learn"))
                HStack(alignment: .bottom) {
                    Text(L("Kế hoạch", "Plan"))
                        .font(Theme.display)
                        .tracking(-0.6)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if !bubbles.isEmpty {
                        Button(L("Làm lại", "Start over")) { reset() }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if bubbles.isEmpty { intro }
                        ForEach(bubbles) { bubble in
                            bubbleView(bubble)
                        }
                        if let draft { draftView(draft) }
                        if busy {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(L("AI đang nghĩ…", "AI is thinking…"))
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        if let errorText { Banner(text: errorText) }
                        if let notice { Banner(text: notice) }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: bubbles.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            if !bubbles.isEmpty, draft == nil, !busy {
                Button {
                    send("", forcePlan: true)
                } label: {
                    Text(L("Cứ đề xuất trước", "Just propose first"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            inputBar
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await restoreConversation() }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L(
                "Chưa cần biết bắt đầu từ đâu. Nói điều bạn muốn học, AI sẽ hỏi vài câu ngắn nếu cần rồi đề xuất các bước đầu tiên. Bạn sửa được mọi thứ trước khi chấp nhận.",
                "You don't need to know where to start. Say what you want to learn; AI asks a few short questions if needed, then proposes the first steps. You can change anything before accepting."
            ))
            .font(.system(size: 15))
            .foregroundStyle(Theme.ink)

            ForEach(examples, id: \.self) { example in
                Button {
                    send(example, forcePlan: false)
                } label: {
                    Text(example)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }

            if contextItems.isEmpty {
                Text(L(
                    "Chưa có context cá nhân. Thêm trong Cài đặt → Context để kế hoạch hợp với bạn hơn; không bắt buộc.",
                    "No personal context yet. Add some under Settings → Context for plans that fit you better; it's optional."
                ))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            }
        }
    }

    private var examples: [String] {
        AppLanguage.current == .vi
            ? ["Mình muốn học Python để phân tích dữ liệu", "Ôn thi môn Xác suất thống kê", "Học vẽ chân dung bằng bút chì"]
            : ["I want to learn Python for data analysis", "Revise for my statistics exam", "Learn pencil portrait drawing"]
    }

    private func bubbleView(_ bubble: Bubble) -> some View {
        VStack(alignment: bubble.fromUser ? .trailing : .leading, spacing: 8) {
            Text(bubble.text)
                .font(.system(size: 15))
                .foregroundStyle(bubble.fromUser ? Theme.onBar : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubble.fromUser ? Theme.bar : Theme.card, in: RoundedRectangle(cornerRadius: 18))

            if !bubble.quickReplies.isEmpty, bubble.id == bubbles.last?.id, !busy {
                FlowLayout(spacing: 8) {
                    ForEach(bubble.quickReplies, id: \.self) { reply in
                        Button {
                            send(reply, forcePlan: false)
                        } label: {
                            Text(reply)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(Theme.card, in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: bubble.fromUser ? .trailing : .leading)
    }

    // MARK: - Kế hoạch đề xuất, sửa được trước khi chấp nhận

    private func draftView(_ current: Draft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(L("Tên mục tiêu", "Goal name"), text: Binding(
                get: { draft?.title ?? "" },
                set: { draft?.title = $0 }
            ))
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(Theme.ink)

            ForEach(current.steps) { step in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField(L("Tên bước", "Step name"), text: stepTitle(step.id), axis: .vertical)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        FlowLayout(spacing: 6) {
                            TagView(text: durationText(step.minutes))
                            TagView(text: L("Tập trung ", "Focus ") + durationText(step.focus) + L(" / nghỉ ", " / break ") + durationText(step.rest))
                        }
                    }
                    Button {
                        draft?.steps.removeAll { $0.id == step.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Bỏ bước này", "Remove this step"))
                }
                .padding(12)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
            }

            if !current.later.isEmpty {
                noteList(L("Chặng sau", "Later on"), current.later)
            }
            if !current.basedOn.isEmpty {
                noteList(L("Dựa trên", "Based on"), current.basedOn)
            }
            if !current.assumptions.isEmpty {
                noteList(L("AI đang giả định (sửa nếu sai)", "AI is assuming (correct it if wrong)"), current.assumptions)
            }

            Button {
                accept()
            } label: {
                PrimaryLabel(title: L("Chấp nhận kế hoạch", "Accept the plan"), systemImage: "checkmark")
            }
            .buttonStyle(.plain)
            .disabled(current.steps.isEmpty)
            .opacity(current.steps.isEmpty ? 0.45 : 1)

            Text(L(
                "Sửa tên, bỏ bước ngay tại đây, hoặc nhắn bên dưới để AI đổi kế hoạch (ví dụ: \"chia bước 2 nhỏ hơn\").",
                "Edit names or remove steps here, or message below to have AI change the plan (e.g. \"split step 2 further\")."
            ))
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func stepTitle(_ id: UUID) -> Binding<String> {
        Binding(
            get: { draft?.steps.first { $0.id == id }?.title ?? "" },
            set: { newValue in
                guard let index = draft?.steps.firstIndex(where: { $0.id == id }) else { return }
                draft?.steps[index].title = newValue
            }
        )
    }

    private func noteList(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: title)
            ForEach(lines, id: \.self) { line in
                Text("• " + line)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 4) {
            TextField(
                "",
                text: $input,
                prompt: Text(
                    draft == nil ? L("Mình muốn học…", "I want to learn…") : L("Nhắn để chỉnh kế hoạch…", "Message to adjust the plan…")
                )
                .foregroundStyle(Theme.barMuted),
                axis: .vertical
            )
            .lineLimit(1...4)
            .foregroundStyle(Theme.onBar)
            .tint(Theme.mark)
            .disabled(busy)

            MicButton(text: $input, tint: Theme.onBar)

            Button {
                send(input, forcePlan: false)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.onMark)
                    .frame(width: 40, height: 40)
                    .background(Theme.mark, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(L("Gửi", "Send"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Theme.bar, in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Hành động

    private func send(_ raw: String, forcePlan: Bool) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, forcePlan || !text.isEmpty else { return }
        errorText = nil
        notice = nil

        if forcePlan {
            let label = L("Cứ đề xuất trước", "Just propose first")
            bubbles.append(Bubble(fromUser: true, text: label))
            history.append(ChatMessage(role: "user", content: label))
        } else {
            // Người dùng tự sửa trên thẻ kế hoạch thì gửi kèm bản hiện tại để AI không ghi đè các sửa đó.
            var content = text
            if let draft {
                let lines = draft.steps.enumerated().map { "\($0.offset + 1). \($0.element.title) (\($0.element.minutes) min)" }
                content += "\n\n(The plan as the user currently has it, after their own edits: \(draft.title)\n" + lines.joined(separator: "\n") + ")"
            }
            bubbles.append(Bubble(fromUser: true, text: text))
            history.append(ChatMessage(role: "user", content: content))
            input = ""
        }

        busy = true
        let promptContext = buildPromptContext(contextItems)
        let messages = history
        Task { @MainActor in
            defer { busy = false }
            do {
                let (turn, rawJSON) = try await AIService().planTurn(history: messages, context: promptContext, forcePlan: forcePlan)
                history.append(ChatMessage(role: "assistant", content: rawJSON))
                if turn.type == "plan", !turn.steps.isEmpty {
                    draft = Draft(
                        title: turn.title,
                        steps: turn.steps.map {
                            DraftStep(
                                title: $0.title,
                                minutes: min(max($0.estimatedMinutes, 15), 480),
                                focus: min(max($0.focusMinutes, 5), 90),
                                rest: min(max($0.breakMinutes, 1), 30)
                            )
                        },
                        later: turn.later,
                        basedOn: turn.basedOn,
                        assumptions: turn.assumptions
                    )
                    bubbles.append(Bubble(fromUser: false, text: turn.message))
                } else {
                    bubbles.append(Bubble(fromUser: false, text: turn.message, quickReplies: turn.quickReplies))
                }
            } catch {
                // Bỏ lượt vừa gửi khỏi lịch sử để lần thử lại không gửi hai lượt người dùng liên tiếp.
                if history.last?.role == "user" { history.removeLast() }
                errorText = error.localizedDescription
            }
        }
    }

    /// Tạo một mục tiêu với các bước đã duyệt. Chưa xếp lịch: lịch được đề xuất và duyệt ở tab Lịch.
    private func accept() {
        guard let draft, !draft.steps.isEmpty else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                let steps: [[String: Any]] = draft.steps.map {
                    ["title": $0.title, "estimated_minutes": $0.minutes, "focus_minutes": $0.focus, "break_minutes": $0.rest]
                }
                try await AIService().acceptPlan(["type": "plan", "message": "", "title": draft.title,
                    "quick_replies": [], "steps": steps, "later": draft.later, "based_on": draft.basedOn, "assumptions": draft.assumptions])
                await SyncCoordinator.shared.sync(context)
                self.draft = nil; bubbles = []; history = []
                notice = L("Đã lưu kế hoạch. Mở tab Lịch để xếp phiên học.", "Plan saved. Open Schedule to plan sessions.")
            } catch { errorText = error.localizedDescription }
        }
    }

    private func restoreConversation() async {
        guard bubbles.isEmpty, let id = UserDefaults.standard.string(forKey: "plannerConversationID") else { return }
        busy = true
        defer { busy = false }
        do {
            let response = try await BackendClient.shared.request("GET", "/v1/conversations/"+id)
            for message in response["messages"] as? [[String: Any]] ?? [] {
                let user = message["role"] as? String == "user"
                if let text = message["content"] as? String { bubbles.append(Bubble(fromUser: user, text: text)) }
                if let turn = message["content"] as? [String: Any], let text = turn["message"] as? String {
                    bubbles.append(Bubble(fromUser: false, text: text, quickReplies: turn["quick_replies"] as? [String] ?? []))
                }
            }
            if let jobID = response["job_id"] as? String {
                let result = try await BackendClient.shared.waitForJob(["job_id": jobID])
                let turn = try BackendClient.shared.decode(PlanTurn.self, result)
                if turn.type == "plan" {
                    draft = Draft(title: turn.title, steps: turn.steps.map { DraftStep(title: $0.title,
                        minutes: $0.estimatedMinutes, focus: $0.focusMinutes, rest: $0.breakMinutes) },
                        later: turn.later, basedOn: turn.basedOn, assumptions: turn.assumptions)
                    UserDefaults.standard.set(result["proposal_id"], forKey: "plannerProposalID")
                    UserDefaults.standard.set(result["proposal_version"], forKey: "plannerProposalVersion")
                }
            }
        } catch { errorText = error.localizedDescription }
    }

    private func reset() {
        UserDefaults.standard.removeObject(forKey: "plannerConversationID")
        UserDefaults.standard.removeObject(forKey: "plannerProposalID")
        bubbles = []
        history = []
        draft = nil
        errorText = nil
        notice = nil
        input = ""
    }
}

#Preview {
    PlannerView()
        .modelContainer(for: [TodoItem.self, ContextItem.self, FocusSession.self], inMemory: true)
}
