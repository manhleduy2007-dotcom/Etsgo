import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var allItems: [TodoItem]

    @State private var filter: TaskCategory?
    @State private var showDone = false
    @State private var captureText = ""
    @State private var isWorking = false
    @State private var banner: String?
    @State private var showingNewItem = false
    @State private var editingItem: TodoItem?
    @FocusState private var captureFocused: Bool

    /// Chỉ công việc gốc; các bước nhỏ hiển thị bên trong công việc cha.
    private var items: [TodoItem] {
        allItems.filter { $0.parent == nil }
    }

    private var visibleItems: [TodoItem] {
        guard let filter else { return items }
        return items.filter { $0.category == filter }
    }

    /// Chưa xong: ưu tiên cao trước, rồi hạn gần nhất, rồi mới tạo nhất.
    private var pendingItems: [TodoItem] {
        visibleItems.filter { !$0.isDone }.sorted { a, b in
            if a.priorityRaw != b.priorityRaw { return a.priorityRaw > b.priorityRaw }
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.createdAt > b.createdAt
            }
        }
    }

    private var doneItems: [TodoItem] {
        visibleItems.filter(\.isDone)
    }

    private var usedCategories: [TaskCategory] {
        TaskCategory.allCases.filter { category in
            items.contains { $0.category == category && !$0.isDone }
        }
    }

    private var remainingMinutes: Int {
        allItems
            .filter { !$0.isDone && $0.subtasks.isEmpty && $0.parent?.isDone != true }
            .reduce(0) { $0 + $1.estimatedMinutes }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            progress
            chips

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(pendingItems) { item in
                        card(for: item)
                    }
                    if pendingItems.isEmpty {
                        emptyState
                    }
                    if !doneItems.isEmpty {
                        Button {
                            withAnimation { showDone.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Eyebrow(text: "Đã xong (\(doneItems.count))")
                                Image(systemName: showDone ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                            }
                            .padding(.top, 10)
                        }
                        .buttonStyle(.plain)
                        if showDone {
                            ForEach(doneItems) { item in
                                card(for: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            if let banner {
                Text(banner)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.ink, lineWidth: 1.5))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .onTapGesture { self.banner = nil }
            } else {
                Text("Gõ như đang nói, AI sẽ tách việc, đặt hạn và phân loại.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            captureBar
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showingNewItem) {
            TodoEditorView(item: nil)
        }
        .sheet(item: $editingItem) { item in
            TodoEditorView(item: item)
        }
    }

    // MARK: - Các phần của màn hình

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            HStack(alignment: .bottom, spacing: 8) {
                Text("Việc cần làm")
                    .font(Theme.display)
                    .tracking(-0.6)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Button {
                    prioritizeWithAI()
                } label: {
                    Label("Ưu tiên", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Theme.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1.5))
                }
                .disabled(isWorking || items.allSatisfy(\.isDone))
                Button {
                    showingNewItem = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1.5))
                }
                .accessibilityLabel("Thêm công việc bằng form")
            }
            .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var progress: some View {
        let done = items.filter(\.isDone).count
        let fraction = items.isEmpty ? 0 : Double(done) / Double(items.count)
        return VStack(spacing: 8) {
            HStack {
                Text("\(done)/\(items.count)").fontWeight(.semibold).foregroundStyle(Theme.ink)
                    + Text(" việc đã xong")
                Spacer()
                Text("Còn ") + Text(durationText(remainingMinutes)).fontWeight(.semibold).foregroundStyle(Theme.ink)
            }
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(Theme.muted)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.ink).frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Tất cả", count: items.filter { !$0.isDone }.count, category: nil)
                ForEach(usedCategories) { category in
                    chip(
                        title: category.title,
                        count: items.filter { $0.category == category && !$0.isDone }.count,
                        category: category
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    private func chip(title: String, count: Int, category: TaskCategory?) -> some View {
        let selected = filter == category
        return Button {
            filter = category
        } label: {
            HStack(spacing: 6) {
                if let category {
                    Circle().fill(category.color).frame(width: 8, height: 8)
                }
                Text("\(title) \(count)")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selected ? Theme.bg : Theme.muted)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(selected ? Theme.ink : Theme.card, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Theme.ink : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func card(for item: TodoItem) -> some View {
        TodoRowView(item: item) {
            editingItem = item
        }
        .contextMenu {
            Button(item.isDone ? "Đánh dấu chưa xong" : "Đánh dấu đã xong", systemImage: "checkmark") {
                item.isDone.toggle()
            }
            Button("Xoá", systemImage: "trash", role: .destructive) {
                context.deleteTodo(item)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text(items.isEmpty ? "Chưa có việc nào" : "Xong hết rồi")
                .font(Theme.dayTitle)
                .foregroundStyle(Theme.ink)
            Text("Gõ một câu vào ô bên dưới để thêm việc.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var captureBar: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: $captureText,
                prompt: Text("Thứ sáu 3 giờ chiều họp khách, tối đi tập gym").foregroundStyle(Theme.barMuted)
            )
            .focused($captureFocused)
            .submitLabel(.send)
            .onSubmit(capture)
            .foregroundStyle(Theme.onBar)
            .tint(Theme.mark)
            .disabled(isWorking)

            Button(action: capture) {
                Group {
                    if isWorking {
                        ProgressView().tint(Theme.onMark)
                    } else {
                        Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(Theme.onMark)
                .frame(width: 40, height: 40)
                .background(Theme.mark, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
            .accessibilityLabel("Thêm")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Theme.bar, in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    // MARK: - AI

    /// Nhập bằng lời: AI tách câu thành các việc đã phân loại.
    private func capture() {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWorking else { return }
        isWorking = true
        banner = "AI đang đọc câu của bạn…"
        Task { @MainActor in
            defer { isWorking = false }
            do {
                let parsed = try await AIService().parseTasks(text: text)
                guard !parsed.isEmpty else { throw AIError.badResponse }
                var names: [String] = []
                for task in parsed {
                    let item = TodoItem(
                        title: task.title,
                        notes: task.notes,
                        dueDate: AIService.parseLocalDate(task.due),
                        priority: Priority(apiName: task.priority) ?? .medium,
                        estimatedMinutes: min(max(task.estimatedMinutes, 15), 480)
                    )
                    item.category = TaskCategory(rawValue: task.category) ?? .other
                    context.insert(item)
                    names.append("\(item.title) (\(item.category.title))")
                }
                captureText = ""
                filter = nil
                banner = "Đã thêm \(parsed.count) việc: " + names.joined(separator: ", ") + "."
            } catch {
                // Không gọi được AI thì vẫn giữ lại điều người dùng vừa gõ.
                context.insert(TodoItem(title: text))
                captureText = ""
                filter = nil
                banner = error.localizedDescription + " Đã thêm nguyên văn câu của bạn vào nhóm Khác."
            }
        }
    }

    /// Gửi các việc chưa xong cho AI và áp dụng mức ưu tiên được đề xuất.
    private func prioritizeWithAI() {
        let targets = items.filter { !$0.isDone }
        guard !targets.isEmpty, !isWorking else { return }

        let payload: [[String: Any]] = targets.enumerated().map { index, task in
            var entry: [String: Any] = [
                "id": String(index + 1),
                "title": task.title,
                "category": task.category.title,
                "estimated_minutes": task.subtasks.isEmpty
                    ? task.estimatedMinutes
                    : task.subtasks.filter { !$0.isDone }.reduce(0) { $0 + $1.estimatedMinutes },
                "current_priority": task.priority.apiName,
            ]
            if !task.notes.isEmpty { entry["notes"] = task.notes }
            if let due = task.dueDate { entry["due"] = AIService.localDateString(due) }
            return entry
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else { return }

        isWorking = true
        banner = "AI đang xem danh sách của bạn…"
        Task { @MainActor in
            defer { isWorking = false }
            do {
                let suggestions = try await AIService().prioritize(tasksJSON: json)
                var changed = 0
                for suggestion in suggestions {
                    guard let number = Int(suggestion.id), targets.indices.contains(number - 1),
                          let priority = Priority(apiName: suggestion.priority)
                    else { continue }
                    let task = targets[number - 1]
                    if task.priority != priority { changed += 1 }
                    task.priority = priority
                    task.aiReason = suggestion.reason
                }
                banner = "AI đã xem \(targets.count) việc và đổi mức ưu tiên của \(changed) việc. "
                    + "Mở từng việc để xem lý do."
            } catch {
                banner = error.localizedDescription
            }
        }
    }
}

#Preview {
    TodoListView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
