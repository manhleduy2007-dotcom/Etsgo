import SwiftUI
import SwiftData

enum TodoFilter: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case pending = "Chưa xong"
    case done = "Đã xong"

    var id: String { rawValue }
}

struct TodoListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var allItems: [TodoItem]

    @State private var searchText = ""
    @State private var filter: TodoFilter = .all
    @State private var quickTitle = ""
    @State private var showingNewItem = false
    @State private var editingItem: TodoItem?
    @State private var isPrioritizing = false
    @State private var alertMessage: String?
    @FocusState private var quickAddFocused: Bool

    /// Chỉ công việc gốc; các bước nhỏ hiển thị bên trong công việc cha.
    private var items: [TodoItem] {
        allItems.filter { $0.parent == nil }
    }

    private var matchingItems: [TodoItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.notes.localizedCaseInsensitiveContains(query)
        }
    }

    /// Chưa xong: ưu tiên cao trước, rồi hạn gần nhất, rồi mới tạo nhất.
    private var pendingItems: [TodoItem] {
        matchingItems.filter { !$0.isDone }.sorted { a, b in
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
        matchingItems.filter(\.isDone)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    quickAddRow
                }

                if filter != .done, !pendingItems.isEmpty {
                    Section("Chưa xong (\(pendingItems.count))") {
                        rows(for: pendingItems)
                    }
                }

                if filter != .pending, !doneItems.isEmpty {
                    Section("Đã xong (\(doneItems.count))") {
                        rows(for: doneItems)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: items.map(\.isDone))
            .overlay { emptyState }
            .navigationTitle("Việc cần làm")
            .searchable(text: $searchText, prompt: "Tìm công việc")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Lọc", selection: $filter) {
                            ForEach(TodoFilter.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if !doneItems.isEmpty {
                            Divider()
                            Button("Xoá việc đã xong", systemImage: "trash", role: .destructive) {
                                doneItems.forEach { context.deleteTodo($0) }
                            }
                        }
                    } label: {
                        Label("Lọc", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isPrioritizing {
                        ProgressView()
                    } else {
                        Button {
                            prioritizeWithAI()
                        } label: {
                            Label("AI đề xuất ưu tiên", systemImage: "sparkles")
                        }
                        .disabled(items.allSatisfy(\.isDone))
                    }
                    Button {
                        showingNewItem = true
                    } label: {
                        Label("Thêm", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewItem) {
                TodoEditorView(item: nil)
            }
            .sheet(item: $editingItem) { item in
                TodoEditorView(item: item)
            }
            .alert(
                "AI đề xuất ưu tiên",
                isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var quickAddRow: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
            TextField("Thêm nhanh công việc…", text: $quickTitle)
                .focused($quickAddFocused)
                .submitLabel(.done)
                .onSubmit(addQuickItem)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if items.isEmpty {
            ContentUnavailableView(
                "Chưa có công việc nào",
                systemImage: "checklist",
                description: Text("Nhập vào ô phía trên hoặc bấm + để thêm việc đầu tiên.")
            )
            .padding(.top, 80)
            .allowsHitTesting(false)
        } else if pendingItems.isEmpty && doneItems.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .padding(.top, 80)
                .allowsHitTesting(false)
        }
    }

    private func rows(for list: [TodoItem]) -> some View {
        ForEach(list) { item in
            TodoRowView(item: item) {
                editingItem = item
            }
            .swipeActions(edge: .trailing) {
                Button("Xoá", systemImage: "trash", role: .destructive) {
                    context.deleteTodo(item)
                }
            }
            .swipeActions(edge: .leading) {
                Button(
                    item.isDone ? "Chưa xong" : "Xong",
                    systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark"
                ) {
                    item.isDone.toggle()
                }
                .tint(item.isDone ? .orange : .green)
            }
        }
    }

    private func addQuickItem() {
        let title = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        context.insert(TodoItem(title: title))
        quickTitle = ""
        quickAddFocused = true
    }

    /// Gửi các việc chưa xong cho AI và áp dụng mức ưu tiên được đề xuất.
    private func prioritizeWithAI() {
        let targets = items.filter { !$0.isDone }
        guard !targets.isEmpty else { return }

        let formatter = ISO8601DateFormatter()
        let payload: [[String: Any]] = targets.enumerated().map { index, task in
            var entry: [String: Any] = [
                "id": String(index + 1),
                "title": task.title,
                "estimated_minutes": task.subtasks.isEmpty
                    ? task.estimatedMinutes
                    : task.subtasks.filter { !$0.isDone }.reduce(0) { $0 + $1.estimatedMinutes },
                "current_priority": task.priority.apiName,
            ]
            if !task.notes.isEmpty { entry["notes"] = task.notes }
            if let due = task.dueDate { entry["due"] = formatter.string(from: due) }
            return entry
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else { return }

        isPrioritizing = true
        Task { @MainActor in
            defer { isPrioritizing = false }
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
                alertMessage = "Đã xem xét \(targets.count) việc, đổi mức ưu tiên của \(changed) việc. "
                    + "Mở từng việc để xem lý do."
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    TodoListView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
