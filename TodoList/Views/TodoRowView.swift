import SwiftData
import SwiftUI

/// Thẻ của một công việc trong danh sách.
struct TodoRowView: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: TodoItem
    var onEdit: () -> Void
    var onStart: () -> Void

    private var totalMinutes: Int {
        item.subtasks.isEmpty ? item.estimatedMinutes : item.subtasks.reduce(0) { $0 + $1.estimatedMinutes }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CheckBox(isOn: item.isDone, color: item.category.color) {
                withAnimation { context.setDone(item, !item.isDone) }
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
                        TagView(text: L("Ưu tiên cao", "High priority"), style: .highlight)
                    }
                    if item.isStuck && !item.isDone {
                        TagView(text: L("Đang vướng", "Stuck"), style: .late)
                    }
                    TagView(text: item.category.title, style: .category(item.category.color))
                    TagView(text: durationText(totalMinutes))
                    if let dueDate = item.dueDate {
                        TagView(text: L("Hạn ", "Due ") + shortDateText(dueDate), style: item.isOverdue ? .late : .plain)
                    }
                    if let start = item.scheduledStart, !item.isDone {
                        TagView(text: L("Đã xếp ", "Planned ") + shortDateText(start), style: item.isMissed ? .late : .plain)
                    }
                    if !item.subtasks.isEmpty {
                        TagView(text: "\(item.subtasks.filter(\.isDone).count)/\(item.subtasks.count) " + L("bước", "steps"))
                    }
                    if item.repeatRule != .none {
                        TagView(text: item.repeatRule.title)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            if !item.isDone {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 34, height: 34)
                        .background(Theme.bg, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Bắt đầu phiên học", "Start a focus session"))
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}
