import Foundation
import SwiftData
import FoodyCore

/// Добавление записей в дневник из продуктов, рецептов и сохранённых приёмов пищи.
enum DiaryService {
    @discardableResult
    static func log(product: Product, amount: Double, category: MealCategory, day: Date, context: ModelContext) -> DiaryEntry {
        let entry = DiaryEntry(day: day, category: category, name: product.name, detail: product.brand, amount: amount,
                               basis: product.basis, per100: product.facts, sourceKind: "product", sourceID: product.uuid)
        product.markUsed()
        context.insert(entry)
        return entry
    }

    /// Рецепт добавляется по весу готового блюда (г).
    @discardableResult
    static func log(recipe: Recipe, amount: Double, category: MealCategory, day: Date, context: ModelContext) -> DiaryEntry {
        let s = recipe.summary
        let portions = s.portionWeight > 0 ? amount / s.portionWeight : 0
        let detail = portions > 0 ? "рецепт · \(NutrientFormatter.grams(portions)) порц." : "рецепт"
        let entry = DiaryEntry(day: day, category: category, name: recipe.name, detail: detail, amount: amount,
                               basis: .grams, per100: s.per100, sourceKind: "recipe", sourceID: recipe.uuid)
        recipe.usageCount += 1
        context.insert(entry)
        return entry
    }

    /// Сохранённый приём пищи разворачивается в отдельные записи с общим `groupID` — каждую можно править.
    @discardableResult
    static func log(meal: SavedMeal, category: MealCategory?, day: Date, context: ModelContext) -> [DiaryEntry] {
        let group = UUID()
        let cat = category ?? meal.category
        var entries: [DiaryEntry] = []
        for item in meal.items {
            let entry = DiaryEntry(day: day, category: cat, name: item.name, detail: meal.name, amount: item.amount,
                                   basis: item.basis, per100: item.per100, sourceKind: "meal", sourceID: item.productID,
                                   groupID: group)
            context.insert(entry)
            entries.append(entry)
        }
        meal.usageCount += 1
        return entries
    }

    /// Быстрая запись без продукта: только КБЖУ.
    @discardableResult
    static func logQuick(name: String, facts: NutritionFacts, category: MealCategory, day: Date, context: ModelContext) -> DiaryEntry {
        let entry = DiaryEntry(day: day, category: category, name: name.isEmpty ? "Быстрая запись" : name, detail: "",
                               amount: 100, basis: .grams, per100: facts, sourceKind: "quick", sourceID: nil)
        context.insert(entry)
        return entry
    }

    static func product(withID id: UUID, context: ModelContext) -> Product? {
        var descriptor = FetchDescriptor<Product>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Все записи за диапазон дней [start, end).
    static func entries(from start: Date, to end: Date, context: ModelContext) -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.day >= start && $0.day < end },
                                                     sortBy: [SortDescriptor(\DiaryEntry.loggedAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func targetSnapshots(context: ModelContext) -> [TargetSnapshot] {
        let descriptor = FetchDescriptor<TargetPlan>(sortBy: [SortDescriptor(\TargetPlan.effectiveFrom)])
        return ((try? context.fetch(descriptor)) ?? []).map { $0.snapshot }
    }

    /// Текущие цели (последний план).
    static func currentPlan(context: ModelContext) -> TargetPlan? {
        var descriptor = FetchDescriptor<TargetPlan>(sortBy: [SortDescriptor(\TargetPlan.effectiveFrom, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Создаёт план по умолчанию при первом запуске.
    static func ensureDefaultPlan(context: ModelContext) {
        if currentPlan(context: context) == nil {
            context.insert(TargetPlan(effectiveFrom: Date(), targets: .standard))
        }
    }
}
