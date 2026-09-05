import Foundation
import SwiftData
import FoodyCore

/// Рецепт: ингредиенты → КБЖУ на 100 г готового блюда (по весу конечного продукта) и на порцию.
@Model
final class Recipe {
    var uuid: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    /// Вес готового блюда после приготовления (г). nil → сумма ингредиентов.
    var finalWeight: Double?
    /// Стандартная порция (г).
    var portionWeight: Double?
    var itemsData: Data = Data()
    /// Кэш значений на 100 г готового блюда.
    var per100Data: Data = Data()
    var kcalPer100: Double = 0
    var proteinPer100: Double = 0
    var fatPer100: Double = 0
    var carbsPer100: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var usageCount: Int = 0

    init(name: String, items: [RecipeItem], finalWeight: Double?, portionWeight: Double?, notes: String = "") {
        self.uuid = UUID()
        self.name = name
        self.notes = notes
        self.finalWeight = finalWeight
        self.portionWeight = portionWeight
        self.createdAt = Date()
        self.updatedAt = Date()
        self.itemsData = Data()
        self.per100Data = Data()
        self.items = items
    }

    var items: [RecipeItem] {
        get { RecipeItem.decode(itemsData) }
        set {
            itemsData = RecipeItem.encode(newValue)
            recalculate()
        }
    }

    var summary: RecipeSummary {
        RecipeMath.summary(items: items.map { $0.input }, finalWeight: finalWeight, portionWeight: portionWeight)
    }

    var per100: NutritionFacts {
        (try? JSONDecoder().decode(NutritionFacts.self, from: per100Data)) ?? NutritionFacts()
    }

    /// Порция в граммах, которую подставляем при добавлении в дневник.
    var effectivePortionWeight: Double {
        let s = summary
        return s.portionWeight > 0 ? s.portionWeight : max(s.finalWeight, 100)
    }

    func recalculate() {
        let s = summary
        per100Data = (try? JSONEncoder().encode(s.per100)) ?? Data()
        kcalPer100 = s.per100.kcal
        proteinPer100 = s.per100.proteinValue
        fatPer100 = s.per100.fatValue
        carbsPer100 = s.per100.carbsValue
        updatedAt = Date()
    }

    var subtitle: String {
        let s = summary
        return "\(NutrientFormatter.kcal(s.perPortion.kcal)) ккал / порция \(NutrientFormatter.grams(s.portionWeight)) г · \(NutrientFormatter.kcal(kcalPer100)) ккал / 100 г"
    }
}
