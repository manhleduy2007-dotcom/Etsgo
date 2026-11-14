import SwiftUI
import SwiftData

/// Dùng cho cả thêm mới (`item == nil`) và chỉnh sửa.
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

    @State private var newSubtaskTitle = ""
    @State private var isBreakingDown = false
    @State private var errorMessage: String?

    init(item: TodoItem?) {
        self.item = item
        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _priority = State(initialValue: item?.priority ?? .medium)
        _hasDueDate = State(initialValue: item?.dueDate != nil)
        _dueDate = State(initialValue: item?.dueDate ?? Date.now.addingTimeInterval(3600))
        _estimatedMinutes = State(initialValue: item?.estimatedMinutes ?? 30)
        _category = State(initialValue: item?.category ?? .other)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tên công việc", text: $title)
                    TextField("Ghi chú", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Picker("Phân loại", selection: $category) {
                        ForEach(TaskCategory.allCases) { category in
                            Label {
                                Text(category.title)
                            } icon: {
                                Image(systemName: "circle.fill").foregroundStyle(category.color)
                            }
                            .tag(category)
                        }
                    }
                    Picker("Ưu tiên", selection: $priority) {
                        ForEach(Priority.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper("Thời lượng: \(estimatedMinutes) phút", value: $estimatedMinutes, in: 15...480, step: 15)
                    Toggle("Có hạn chót", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Hạn chót", selection: $dueDate)
                    }
                } footer: {
                    if let reason = item?.aiReason, !reason.isEmpty {
                        Text("Lý do AI đề xuất mức ưu tiên: \(reason)")
                    }
                }

                if let item {
                    subtaskSection(for: item)

                    Section {
                        Button("Xoá công việc", role: .destructive) {
                            context.deleteTodo(item)
                            dismiss()
                        }
                    }
                } else {
                    Section {
                    } footer: {
                        Text("Lưu công việc rồi mở lại để chia thành các bước nhỏ bằng AI.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.ink)
            .navigationTitle(item == nil ? "Việc mới" : "Sửa công việc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu", action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .alert(
                "Không chia nhỏ được",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func subtaskSection(for item: TodoItem) -> some View {
        Section {
            ForEach(item.sortedSubtasks) { sub in
                HStack {
                    Button {
                        toggle(sub, in: item)
                    } label: {
                        Image(systemName: sub.isDone ? "checkmark.square.fill" : "square")
                            .foregroundStyle(sub.isDone ? item.category.color : Theme.muted)
                    }
                    .buttonStyle(.plain)
                    Text(sub.title)
                        .strikethrough(sub.isDone)
                        .foregroundStyle(sub.isDone ? .secondary : .primary)
                    Spacer(minLength: 8)
                    Text("\(sub.estimatedMinutes) phút")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                let subs = item.sortedSubtasks
                offsets.map { subs[$0] }.forEach { context.deleteTodo($0) }
            }

            TextField("Thêm bước…", text: $newSubtaskTitle)
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
                        Text("AI đang chia nhỏ…")
                    }
                } else {
                    Label("AI chia nhỏ công việc", systemImage: "sparkles")
                }
            }
            .disabled(isBreakingDown || trimmedTitle.isEmpty)
        } header: {
            Text("Các bước nhỏ")
        } footer: {
            Text("Khi có các bước nhỏ, bộ xếp lịch sẽ xếp từng bước thay cho cả công việc.")
        }
    }

    private func toggle(_ sub: TodoItem, in item: TodoItem) {
        sub.isDone.toggle()
        // Xong hết các bước thì công việc cha cũng xong.
        if item.subtasks.allSatisfy(\.isDone) {
            item.isDone = true
        } else if !sub.isDone {
            item.isDone = false
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
                    let minutes = min(max(step.estimatedMinutes, 15), 480)
                    item.addSubtask(title: step.title, estimatedMinutes: minutes)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func save() {
        let due = hasDueDate ? dueDate : nil
        if let item {
            item.title = trimmedTitle
            item.notes = notes
            item.priority = priority
            item.dueDate = due
            item.estimatedMinutes = estimatedMinutes
            item.category = category
        } else {
            let newItem = TodoItem(
                title: trimmedTitle,
                notes: notes,
                dueDate: due,
                priority: priority,
                estimatedMinutes: estimatedMinutes
            )
            newItem.category = category
            context.insert(newItem)
        }
        dismiss()
    }
}

#Preview {
    TodoEditorView(item: nil)
        .modelContainer(for: TodoItem.self, inMemory: true)
}
