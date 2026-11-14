import SwiftUI
import SwiftData

@main
struct TodoListApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: TodoItem.self)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodoListView()
                .tabItem { Label("Công việc", systemImage: "checklist") }
            ScheduleView()
                .tabItem { Label("Lịch", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Cài đặt", systemImage: "gearshape") }
        }
    }
}
