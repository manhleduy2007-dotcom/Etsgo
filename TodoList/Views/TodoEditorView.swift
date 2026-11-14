import SwiftUI
import SwiftData

/// Dùng cho cả thêm mới (`item == nil`) và chỉnh sửa. Mọi thông tin ngoài tên đều có thể để trống.
struct TodoEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: TodoItem?

    @State private var title: String
    @State private var notes: String
    @State private var priority: Priority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var estimatedMinutes: Int
    @State private var category: TaskCategory
    @State private var remind: Bool
    @State private var repeatRule: RepeatRule
    @State private var focusMinutes: Int
    @State private var breakMinutes: Int

    @State private var newSubtaskTitle = ""
    @State private var isBreakingDown = false
    @State private var errorMessage: String?
    @State private var startingItem: TodoItem?

    init(item: TodoItem?) {
        self.item = item
        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _priority = State(initialValue: item?.priority ?? .medium)
        _hasDueDate = State(initialValue: item?.dueDate != nil)
        _dueDate = State(initialValue: item?.dueDate ?? Date.now.addingTimeInterval(3600))
        _estimatedMinutes = State(initialValue: item?.estimatedMinutes ?? 30)
        _category = State(initialValue: item?.category ?? .study)
        _remind = State(initialValue: item?.remind ?? false)
        _repeatRule = State(initialValue: item?.repeatRule ?? .none)
        _focusMinutes = State(initialValue: item?.focusMinutes ?? 25)
        _breakMinutes = State(initialValue: item?.breakMinutes ?? 5)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("Tên công việc", "Task name"), text: $title)
                    TextField(L("Ghi chú", "Notes"), text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Picker(L("Danh sách", "List"), selection: $category) {
                        ForEach(TaskCategory.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker(L("Ưu tiên", "Priority"), selection: $priority) {
                        ForEach(Priority.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(
                        L("Thời lượng: ", "Duration: ") + durationText(estimatedMinutes),
                        value: $estimatedMinutes, in: 15...480, step: 15
                    )
                } footer: {
                    if let reason = item?.aiReason, !reason.isEmpty {
                        Text(L("Lý do AI đề xuất mức ưu tiên: ", "Why AI suggested this priority: ") + reason)
                    }
                }

                Section {
                    Toggle(L("Có hạn chót", "Has a due date"), isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker(L("Hạn chót", "Due"), selection: $dueDate)
                    }
                    Toggle(L("Nhắc việc", "Remind me"), isOn: $remind)
                    Picker(L("Lặp lại", "Repeat"), selection: $repeatRule) {
                        ForEach(RepeatRule.allCases) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text(L(
                        "Lời nhắc báo vào giờ đã xếp lịch, nếu chưa xếp thì vào hạn chót. Việc lặp lại tạo bản tiếp theo khi bạn hoàn thành.",
                        "The reminder fires at the planned time, or at the due date if none. A repeating task creates its next copy when you complete it."
                    ))
                }

                Section(L("Phiên tập trung", "Focus session")) {
                    Stepper(L("Tập trung: ", "Focus: ") + durationText(focusMinutes), value: $focusMinutes, in: 5...90, step: 5)
                    Stepper(L("Nghỉ: ", "Break: ") + durationText(breakMinutes), value: $breakMinutes, in: 1...30)
                    if let item, !item.isDone {
                        Button {
                            applyEdits(to: item)
                            startingItem = item.sortedSubtasks.first { !$0.isDone } ?? item
                        } label: {
                            Label(L("Bắt đầu phiên học", "Start a focus session"), systemImage: "play.fill")
                        }
                    }
                }

                if let item {
                    subtaskSection(for: item)

                    Section {
                        Button(L("Xoá công việc", "Delete task"), role: .destructive) {
                            context.deleteTodo(item)
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.ink)
            .navigationTitle(item == nil ? L("Việc mới", "New task") : L("Sửa công việc", "Edit task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Huỷ", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Lưu", "Save"), action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .alert(
                L("Không chia nhỏ được", "Could not break it down"),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .fullScreenCover(item: $startingItem) { target in
                PomodoroView(item: target)
            }
            .onChange(of: remind) { _, isOn in
                if isOn { Task { _ = await NotificationService.requestAccess() } }
            }
        }
    }

    private func subtaskSection(for item: TodoItem) -> some View {
        Section {
            ForEach(item.sortedSubtasks) { sub in
                HStack {
                    Button {
                        context.setDone(sub, !sub.isDone)
                    } label: {
                        Image(systemName: sub.isDone ? "checkmark.square.fill" : "square")
                            .foregroundStyle(sub.isDone ? item.category.color : Theme.muted)
                    }
                    .buttonStyle(.plain)
                    Text(sub.title)
                        .strikethrough(sub.isDone)
                        .foregroundStyle(sub.isDone ? Theme.muted : Theme.ink)
                    Spacer(minLength: 8)
                    Text(durationText(sub.estimatedMinutes))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .onDelete { offsets in
                let subs = item.sortedSubtasks
                offsets.map { subs[$0] }.forEach { context.deleteTodo($0) }
            }

            TextField(L("Thêm bước…", "Add a step…"), text: $newSubtaskTitle)
                .submitLabel(.done)
                .onSubmit {
                    let text = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    item.addSubtask(title: text)
                    newSubtaskTitle = ""
                }

            Button {
                breakDown(item)
            } label: {
                if isBreakingDown {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L("AI đang chia nhỏ…", "AI is breaking it down…"))
                    }
                } else {
                    Label(L("AI chia nhỏ công việc", "Break down with AI"), systemImage: "sparkles")
                }
            }
            .disabled(isBreakingDown || trimmedTitle.isEmpty)
        } header: {
            Text(L("Các bước", "Steps"))
        } footer: {
            Text(L(
                "Khi có các bước, lịch được xếp theo từng bước và giữ đúng thứ tự.",
                "When a task has steps, each step is planned separately and in order."
            ))
        }
    }

    private func breakDown(_ item: TodoItem) {
        let taskTitle = trimmedTitle
        let taskNotes = notes
        isBreakingDown = true
        Task { @MainActor in
            defer { isBreakingDown = false }
            do {
                let steps = try await AIService().breakdown(title: taskTitle, notes: taskNotes)
                for step in steps {
                    item.addSubtask(title: step.title, estimatedMinutes: min(max(step.estimatedMinutes, 15), 480))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyEdits(to target: TodoItem) {
        target.title = trimmedTitle.isEmpty ? target.title : trimmedTitle
        target.notes = notes
        target.priority = priority
        target.dueDate = hasDueDate ? dueDate : nil
        target.estimatedMinutes = estimatedMinutes
        target.category = category
        target.remind = remind
        target.repeatRule = repeatRule
        target.focusMinutes = focusMinutes
        target.breakMinutes = breakMinutes
        NotificationService.scheduleReminder(for: target)
    }

    private func save() {
        if let item {
            applyEdits(to: item)
        } else {
            let newItem = TodoItem(title: trimmedTitle)
            context.insert(newItem)
            applyEdits(to: newItem)
        }
        dismiss()
    }
}

#Preview {
    TodoEditorView(item: nil)
        .modelContainer(for: [TodoItem.self, ContextItem.self, FocusSession.self], inMemory: true)
}
