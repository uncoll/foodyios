import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            DiaryView()
                .tabItem { Label("Дневник", systemImage: "book.closed") }
            LibraryView()
                .tabItem { Label("Продукты", systemImage: "carrot") }
            StatsView()
                .tabItem { Label("Статистика", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .task {
            DiaryService.ensureDefaultPlan(context: context)
        }
    }
}
