import Foundation
import SwiftData

enum FoodySchema {
    static let models: [any PersistentModel.Type] = [Product.self, Recipe.self, SavedMeal.self, DiaryEntry.self, TargetPlan.self]

    /// Локальное хранилище без iCloud.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration("Foody", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
