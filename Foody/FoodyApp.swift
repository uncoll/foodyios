import SwiftUI
import SwiftData

@main
struct FoodyApp: App {
    @StateObject private var settings = AppSettings()
    let container: ModelContainer

    init() {
        do {
            container = try FoodySchema.makeContainer()
        } catch {
            // Крайний случай (повреждённая база): работаем в памяти, чтобы приложение хотя бы открылось.
            do {
                container = try FoodySchema.makeContainer(inMemory: true)
            } catch {
                fatalError("Не удалось создать хранилище SwiftData: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(settings)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
