import SwiftUI
import SwiftData

@main
struct TodoListApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [TodoItem.self, ContextItem.self, FocusSession.self, SyncRecord.self, PendingOperation.self, PlannedSession.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var backend = BackendClient.shared
    @State private var restoredTask: TodoItem?
    @AppStorage("language") private var language = "vi"
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        Group {
        if !backend.signedIn { AccountView() }
        else { TabView {
            TodoListView()
                .tabItem { Label(L("Công việc", "Tasks"), systemImage: "checklist") }
            PlannerView()
                .tabItem { Label(L("Kế hoạch", "Plan"), systemImage: "sparkles") }
            ScheduleView()
                .tabItem { Label(L("Lịch", "Schedule"), systemImage: "calendar") }
            SettingsView()
                .tabItem { Label(L("Cài đặt", "Settings"), systemImage: "slider.horizontal.3") }
        }
        .tint(Theme.ink)
        // Dựng lại toàn bộ giao diện khi đổi ngôn ngữ; dữ liệu nằm trong SwiftData nên không mất.
        .id(language)
        .fullScreenCover(isPresented: Binding(get: { !onboarded }, set: { if !$0 { onboarded = true } })) {
            OnboardingView { onboarded = true }
        }
        }
        }
        .task(id: backend.userID) {
            if let data = UserDefaults.standard.data(forKey: "activePomodoro"),
               let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               value["owner"] as? String == backend.userID,
               let id = value["task_id"] as? String {
                restoredTask = (try? context.fetch(FetchDescriptor<TodoItem>()))?.first { $0.uid == id }
            }
            while !Task.isCancelled && backend.signedIn {
                await SyncCoordinator.shared.sync(context)
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
        .fullScreenCover(item: $restoredTask) { PomodoroView(item: $0) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await SyncCoordinator.shared.sync(context) } }
            if phase == .inactive { try? SyncCoordinator.shared.capture(context) }
        }
    }
}
