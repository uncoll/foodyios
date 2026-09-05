import Foundation

/// Ингредиент рецепта / состав сохранённого приёма пищи: количество и значения продукта на 100 г/мл.
public struct IngredientInput: Equatable, Sendable {
    public var amount: Double          // г или мл
    public var per100: NutritionFacts

    public init(amount: Double, per100: NutritionFacts) {
        self.amount = amount
        self.per100 = per100
    }

    public var nutrients: NutritionFacts { per100.forAmount(amount) }
}

/// Расчёт КБЖУ рецепта: сумма ингредиентов → на 100 г готового блюда (по весу конечного продукта) → на порцию.
public enum RecipeMath {
    /// Сумма по всем ингредиентам.
    public static func total(_ items: [IngredientInput]) -> NutritionFacts {
        NutritionFacts.sum(items.map { $0.nutrients })
    }

    /// Суммарная масса сырых ингредиентов.
    public static func rawWeight(_ items: [IngredientInput]) -> Double {
        items.reduce(0) { $0 + $1.amount }
    }

    /// Значения на 100 г готового блюда. `finalWeight` — взвешенный вес после приготовления
    /// (учитывает выкипание/впитывание воды); если он не задан или ≤ 0, берётся масса сырых ингредиентов.
    public static func per100(total: NutritionFacts, finalWeight: Double?, rawWeight: Double) -> NutritionFacts {
        let weight = (finalWeight ?? 0) > 0 ? finalWeight! : rawWeight
        guard weight > 0 else { return .empty }
        return total.scaled(by: 100 / weight)
    }

    /// Значения на одну стандартную порцию заданного веса.
    public static func portion(per100: NutritionFacts, portionWeight: Double) -> NutritionFacts {
        per100.forAmount(portionWeight)
    }

    /// Полный расчёт.
    public static func summary(items: [IngredientInput], finalWeight: Double?, portionWeight: Double?) -> RecipeSummary {
        let raw = rawWeight(items)
        let total = total(items)
        let weight = (finalWeight ?? 0) > 0 ? finalWeight! : raw
        let per100 = per100(total: total, finalWeight: weight, rawWeight: raw)
        let portionW = (portionWeight ?? 0) > 0 ? portionWeight! : weight
        return RecipeSummary(rawWeight: raw, finalWeight: weight, total: total, per100: per100,
                             portionWeight: portionW, perPortion: portion(per100: per100, portionWeight: portionW),
                             portionsCount: portionW > 0 ? weight / portionW : 0)
    }
}

public struct RecipeSummary: Equatable, Sendable {
    public var rawWeight: Double
    public var finalWeight: Double
    public var total: NutritionFacts
    public var per100: NutritionFacts
    public var portionWeight: Double
    public var perPortion: NutritionFacts
    public var portionsCount: Double

    public init(rawWeight: Double, finalWeight: Double, total: NutritionFacts, per100: NutritionFacts, portionWeight: Double,
                perPortion: NutritionFacts, portionsCount: Double) {
        self.rawWeight = rawWeight
        self.finalWeight = finalWeight
        self.total = total
        self.per100 = per100
        self.portionWeight = portionWeight
        self.perPortion = perPortion
        self.portionsCount = portionsCount
    }
}
