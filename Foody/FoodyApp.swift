import SwiftUI
import SwiftData

@main
struct FoodyApp: App {
    @State private var settings = AppSettings()
    let container: ModelContainer

    init() {
        do {
            container = try FoodySchema.makeContainer()
        } catch {
            // Крайний случай (повреждённая база): работаем в памяти, чтобы приложение хотя бы открылось.
            container = (try? FoodySchema.makeContainer(inMemory: true))!
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(settings)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
