import Foundation
import SwiftData
import FoodyCore

/// Резервная копия всех данных в один JSON-файл (для переноса на новый телефон или просмотра).
enum DataExport {
    struct Backup: Codable {
        var exportedAt: Date
        var version: Int
        var products: [ProductRecord]
        var recipes: [RecipeRecord]
        var meals: [MealRecord]
        var diary: [EntryRecord]
        var targets: [TargetRecord]
    }

    struct ProductRecord: Codable {
        var id: UUID; var name: String; var brand: String; var basis: String; var servingSize: Double?; var servingName: String?
        var facts: NutritionFacts; var notes: String; var isFavorite: Bool; var source: String; var createdAt: Date
    }

    struct RecipeRecord: Codable {
        var id: UUID; var name: String; var notes: String; var finalWeight: Double?; var portionWeight: Double?; var items: [RecipeItem]
    }

    struct MealRecord: Codable {
        var id: UUID; var name: String; var category: String; var items: [RecipeItem]
    }

    struct EntryRecord: Codable {
        var id: UUID; var day: Date; var loggedAt: Date; var category: String; var name: String; var detail: String
        var amount: Double; var basis: String; var per100: NutritionFacts; var sourceKind: String; var sourceID: UUID?; var groupID: UUID?
    }

    struct TargetRecord: Codable {
        var effectiveFrom: Date; var targets: DailyTargets
    }

    static func makeBackup(context: ModelContext) throws -> Data {
        let products = try context.fetch(FetchDescriptor<Product>())
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        let meals = try context.fetch(FetchDescriptor<SavedMeal>())
        let entries = try context.fetch(FetchDescriptor<DiaryEntry>())
        let plans = try context.fetch(FetchDescriptor<TargetPlan>())
        let backup = Backup(
            exportedAt: Date(), version: 1,
            products: products.map { ProductRecord(id: $0.uuid, name: $0.name, brand: $0.brand, basis: $0.basisRaw, servingSize: $0.servingSize,
                                                   servingName: $0.servingName, facts: $0.facts, notes: $0.notes, isFavorite: $0.isFavorite,
                                                   source: $0.sourceRaw, createdAt: $0.createdAt) },
            recipes: recipes.map { RecipeRecord(id: $0.uuid, name: $0.name, notes: $0.notes, finalWeight: $0.finalWeight,
                                                portionWeight: $0.portionWeight, items: $0.items) },
            meals: meals.map { MealRecord(id: $0.uuid, name: $0.name, category: $0.categoryRaw, items: $0.items) },
            diary: entries.map { EntryRecord(id: $0.uuid, day: $0.day, loggedAt: $0.loggedAt, category: $0.categoryRaw, name: $0.name,
                                             detail: $0.detail, amount: $0.amount, basis: $0.basisRaw, per100: $0.per100,
                                             sourceKind: $0.sourceKindRaw, sourceID: $0.sourceID, groupID: $0.groupID) },
            targets: plans.map { TargetRecord(effectiveFrom: $0.effectiveFrom, targets: $0.targets) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    /// Восстановление из резервной копии: добавляет отсутствующие записи (по id), существующие не трогает.
    static func restore(from data: Data, context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: data)
        var added = 0
        let existingProducts = Set((try context.fetch(FetchDescriptor<Product>())).map { $0.uuid })
        for p in backup.products where !existingProducts.contains(p.id) {
            let product = Product(name: p.name, brand: p.brand, basis: MeasureBasis(rawValue: p.basis) ?? .grams, facts: p.facts,
                                  servingSize: p.servingSize, servingName: p.servingName, notes: p.notes, source: p.source)
            product.uuid = p.id
            product.isFavorite = p.isFavorite
            product.createdAt = p.createdAt
            context.insert(product)
            added += 1
        }
        let existingRecipes = Set((try context.fetch(FetchDescriptor<Recipe>())).map { $0.uuid })
        for r in backup.recipes where !existingRecipes.contains(r.id) {
            let recipe = Recipe(name: r.name, items: r.items, finalWeight: r.finalWeight, portionWeight: r.portionWeight, notes: r.notes)
            recipe.uuid = r.id
            context.insert(recipe)
            added += 1
        }
        let existingMeals = Set((try context.fetch(FetchDescriptor<SavedMeal>())).map { $0.uuid })
        for m in backup.meals where !existingMeals.contains(m.id) {
            let meal = SavedMeal(name: m.name, category: MealCategory(rawValue: m.category) ?? .breakfast, items: m.items)
            meal.uuid = m.id
            context.insert(meal)
            added += 1
        }
        let existingEntries = Set((try context.fetch(FetchDescriptor<DiaryEntry>())).map { $0.uuid })
        for e in backup.diary where !existingEntries.contains(e.id) {
            let entry = DiaryEntry(day: e.day, category: MealCategory(rawValue: e.category) ?? .snack, name: e.name, detail: e.detail,
                                   amount: e.amount, basis: MeasureBasis(rawValue: e.basis) ?? .grams, per100: e.per100,
                                   sourceKind: e.sourceKind, sourceID: e.sourceID, groupID: e.groupID, loggedAt: e.loggedAt)
            entry.uuid = e.id
            context.insert(entry)
            added += 1
        }
        let existingPlans = Set((try context.fetch(FetchDescriptor<TargetPlan>())).map { $0.effectiveFrom })
        for t in backup.targets where !existingPlans.contains(t.effectiveFrom) {
            context.insert(TargetPlan(effectiveFrom: t.effectiveFrom, targets: t.targets))
            added += 1
        }
        return added
    }
}
