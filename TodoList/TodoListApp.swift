import SwiftUI
import SwiftData

@main
struct TodoListApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [TodoItem.self, ContextItem.self, FocusSession.self])
    }
}

struct RootView: View {
    @AppStorage("language") private var language = "vi"
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        TabView {
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
