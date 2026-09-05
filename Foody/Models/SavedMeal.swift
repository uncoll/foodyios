import Foundation
import SwiftData
import FoodyCore

/// Сохранённый приём пищи («мой обычный завтрак»): набор продуктов с количествами, добавляется в дневник одним касанием.
@Model
final class SavedMeal {
    var uuid: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = MealCategory.breakfast.rawValue
    var itemsData: Data = Data()
    var kcal: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var usageCount: Int = 0

    init(name: String, category: MealCategory, items: [RecipeItem]) {
        self.uuid = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.itemsData = Data()
        self.items = items
    }

    var category: MealCategory {
        get { MealCategory(rawValue: categoryRaw) ?? .breakfast }
        set { categoryRaw = newValue.rawValue }
    }

    var items: [RecipeItem] {
        get { RecipeItem.decode(itemsData) }
        set {
            itemsData = RecipeItem.encode(newValue)
            let total = NutritionFacts.sum(newValue.map { $0.nutrients })
            kcal = total.kcal
            protein = total.proteinValue
            fat = total.fatValue
            carbs = total.carbsValue
            updatedAt = Date()
        }
    }

    var total: NutritionFacts { NutritionFacts.sum(items.map { $0.nutrients }) }

    var subtitle: String {
        "\(items.count) \(pluralItems(items.count)) · \(NutrientFormatter.kcal(kcal)) ккал"
    }

    private func pluralItems(_ n: Int) -> String {
        let r10 = n % 10, r100 = n % 100
        if r10 == 1 && r100 != 11 { return "продукт" }
        if (2...4).contains(r10) && !(12...14).contains(r100) { return "продукта" }
        return "продуктов"
    }
}
