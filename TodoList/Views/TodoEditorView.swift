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

    init(item: TodoItem?) {
        self.item = item
        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _priority = State(initialValue: item?.priority ?? .medium)
        _hasDueDate = State(initialValue: item?.dueDate != nil)
        _dueDate = State(initialValue: item?.dueDate ?? Date.now.addingTimeInterval(3600))
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
                    Picker("Ưu tiên", selection: $priority) {
                        ForEach(Priority.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Có hạn chót", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Hạn chót", selection: $dueDate)
                    }
                }

                if let item {
                    Section {
                        Button("Xoá công việc", role: .destructive) {
                            context.delete(item)
                            dismiss()
                        }
                    }
                }
            }
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
        }
    }

    private func save() {
        let due = hasDueDate ? dueDate : nil
        if let item {
            item.title = trimmedTitle
            item.notes = notes
            item.priority = priority
            item.dueDate = due
        } else {
            context.insert(
                TodoItem(title: trimmedTitle, notes: notes, dueDate: due, priority: priority)
            )
        }
        dismiss()
    }
}

#Preview {
    TodoEditorView(item: nil)
        .modelContainer(for: TodoItem.self, inMemory: true)
}
