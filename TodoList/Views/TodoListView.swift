import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var allItems: [TodoItem]

    @State private var filter: TaskCategory?
    @State private var showDone = false
    @State private var searching = false
    @State private var searchText = ""
    @State private var captureText = ""
    @State private var isWorking = false
    @State private var banner: String?
    @State private var showingNewItem = false
    @State private var editingItem: TodoItem?
    @State private var startingItem: TodoItem?

    /// Chỉ công việc gốc; các bước nhỏ hiển thị bên trong công việc cha.
    private var items: [TodoItem] {
        allItems.filter { $0.parent == nil }
    }

    private var visibleItems: [TodoItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            (filter == nil || item.category == filter)
                && (query.isEmpty
                    || item.title.localizedCaseInsensitiveContains(query)
                    || item.notes.localizedCaseInsensitiveContains(query)
                    || item.subtasks.contains { $0.title.localizedCaseInsensitiveContains(query) })
        }
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
            if searching { searchField }
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
                                Eyebrow(text: L("Đã xong", "Done") + " (\(doneItems.count))")
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
                Banner(text: banner)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .onTapGesture { self.banner = nil }
            } else {
                Text(L(
                    "Gõ hoặc nói như bình thường, AI sẽ tách việc, đặt hạn và phân loại.",
                    "Type or speak naturally; AI splits it into tasks, sets dates and sorts them."
                ))
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
        .fullScreenCover(item: $startingItem) { item in
            PomodoroView(item: item)
        }
    }

    // MARK: - Các phần của màn hình

    private func roundButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Theme.card, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1.5))
        }
        .accessibilityLabel(label)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: dayText(.now))
            HStack(alignment: .bottom, spacing: 8) {
                Text(L("Việc cần làm", "To do"))
                    .font(Theme.display)
                    .tracking(-0.6)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                roundButton("sparkles", label: L("AI đề xuất ưu tiên", "AI priority suggestions")) {
                    prioritizeWithAI()
                }
                .disabled(isWorking || items.allSatisfy(\.isDone))
                roundButton("magnifyingglass", label: L("Tìm kiếm", "Search")) {
                    withAnimation { searching.toggle() }
                    if !searching { searchText = "" }
                }
                roundButton("plus", label: L("Thêm công việc bằng form", "Add a task with the form")) {
                    showingNewItem = true
                }
            }
            .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField(L("Tìm công việc", "Search tasks"), text: $searchText)
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var progress: some View {
        let done = items.filter(\.isDone).count
        let fraction = items.isEmpty ? 0 : Double(done) / Double(items.count)
        return VStack(spacing: 8) {
            HStack {
                Text("\(done)/\(items.count) " + L("việc đã xong", "tasks done"))
                Spacer()
                Text(L("Còn ", "Left: ") + durationText(remainingMinutes))
            }
            .font(.system(size: 13, weight: .medium).monospacedDigit())
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
                chip(title: L("Tất cả", "All"), count: items.filter { !$0.isDone }.count, category: nil)
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
        } onStart: {
            // Việc có bước nhỏ thì bắt đầu từ bước chưa xong đầu tiên.
            startingItem = item.sortedSubtasks.first { !$0.isDone } ?? item
        }
        .contextMenu {
            Button(
                item.isDone ? L("Mở lại", "Reopen") : L("Đánh dấu đã xong", "Mark as done"),
                systemImage: "checkmark"
            ) {
                context.setDone(item, !item.isDone)
            }
            Button(L("Xoá", "Delete"), systemImage: "trash", role: .destructive) {
                context.deleteTodo(item)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text(
                items.isEmpty ? L("Chưa có việc nào", "Nothing here yet")
                    : (searchText.isEmpty ? L("Xong hết rồi", "All done") : L("Không tìm thấy", "No matches"))
            )
            .font(Theme.dayTitle)
            .foregroundStyle(Theme.ink)
            Text(L(
                "Gõ một câu vào ô bên dưới, hoặc mở tab Kế hoạch để lập kế hoạch học.",
                "Type a sentence below, or open the Plan tab to plan something you want to learn."
            ))
            .font(.system(size: 14))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var captureBar: some View {
        HStack(spacing: 4) {
            TextField(
                "",
                text: $captureText,
                prompt: Text(L("Thứ sáu 3 giờ chiều nộp bài tập Toán", "Hand in math homework Friday 3pm"))
                    .foregroundStyle(Theme.barMuted)
            )
            .submitLabel(.send)
            .onSubmit(capture)
            .foregroundStyle(Theme.onBar)
            .tint(Theme.mark)
            .disabled(isWorking)

            MicButton(text: $captureText, tint: Theme.onBar)

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
            .accessibilityLabel(L("Thêm", "Add"))
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
        banner = L("AI đang đọc câu của bạn…", "AI is reading your sentence…")
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
                banner = L("Đã thêm \(parsed.count) việc: ", "Added \(parsed.count): ") + names.joined(separator: ", ") + "."
            } catch {
                // Không gọi được AI thì vẫn giữ lại điều người dùng vừa gõ; tạo việc không phụ thuộc AI.
                context.insert(TodoItem(title: text))
                captureText = ""
                filter = nil
                banner = error.localizedDescription
                    + L(" Đã thêm nguyên văn câu của bạn vào nhóm Khác.", " Your sentence was added as-is under Other.")
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
                "list": task.category.rawValue,
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
        banner = L("AI đang xem danh sách của bạn…", "AI is looking at your list…")
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
                banner = L(
                    "AI đã xem \(targets.count) việc và đổi mức ưu tiên của \(changed) việc. Mở từng việc để xem lý do.",
                    "AI reviewed \(targets.count) tasks and changed the priority of \(changed). Open a task to see why."
                )
            } catch {
                banner = error.localizedDescription
            }
        }
    }
}

#Preview {
    TodoListView()
        .modelContainer(for: [TodoItem.self, ContextItem.self, FocusSession.self], inMemory: true)
}
