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
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var items: [TodoItem]

    @State private var searchText = ""
    @State private var filter: TodoFilter = .all
    @State private var quickTitle = ""
    @State private var showingNewItem = false
    @State private var editingItem: TodoItem?
    @FocusState private var quickAddFocused: Bool

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
                                doneItems.forEach(context.delete)
                            }
                        }
                    } label: {
                        Label("Lọc", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                    context.delete(item)
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
}

#Preview {
    TodoListView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
