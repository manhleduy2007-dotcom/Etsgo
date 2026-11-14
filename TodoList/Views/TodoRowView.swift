import SwiftUI

struct TodoRowView: View {
    @Bindable var item: TodoItem
    var onEdit: () -> Void

    private var doneSubtasks: Int {
        item.subtasks.filter(\.isDone).count
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation { item.isDone.toggle() }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Đánh dấu chưa xong" : "Đánh dấu đã xong")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let dueDate = item.dueDate {
                    Label(
                        "Hạn: " + dueDate.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "flag"
                    )
                    .font(.caption)
                    .foregroundStyle(item.isOverdue ? Color.red : Color.secondary)
                }

                if let start = item.scheduledStart, !item.isDone {
                    Label(
                        "Đã xếp: " + start.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(.tint)
                }

                if !item.subtasks.isEmpty {
                    Label("\(doneSubtasks)/\(item.subtasks.count) bước", systemImage: "list.bullet.indent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if item.priority == .high && !item.isDone {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Ưu tiên cao")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
