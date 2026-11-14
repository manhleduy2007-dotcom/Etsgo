import SwiftUI

/// Thẻ của một công việc trong danh sách.
struct TodoRowView: View {
    @Bindable var item: TodoItem
    var onEdit: () -> Void

    private var totalMinutes: Int {
        item.subtasks.isEmpty ? item.estimatedMinutes : item.subtasks.reduce(0) { $0 + $1.estimatedMinutes }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CheckBox(isOn: item.isDone, color: item.category.color) {
                withAnimation { item.isDone.toggle() }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 16, weight: item.isDone ? .medium : .semibold))
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? Theme.muted : Theme.ink)

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }

                FlowLayout(spacing: 6) {
                    if item.priority == .high && !item.isDone {
                        TagView(text: "Ưu tiên cao", style: .highlight)
                    }
                    TagView(text: item.category.title, style: .category(item.category.color))
                    TagView(text: durationText(totalMinutes))
                    if let dueDate = item.dueDate {
                        TagView(text: "Hạn " + shortDateText(dueDate), style: item.isOverdue ? .late : .plain)
                    }
                    if let start = item.scheduledStart, !item.isDone {
                        TagView(text: "Đã xếp " + shortDateText(start))
                    }
                    if !item.subtasks.isEmpty {
                        TagView(text: "\(item.subtasks.filter(\.isDone).count)/\(item.subtasks.count) bước")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}
