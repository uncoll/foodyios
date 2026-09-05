import Foundation
import SwiftData
import FoodyCore

/// Запись дневника. Хранит снимок значений на 100 г/мл и количество — история не меняется при правке продукта.
@Model
final class DiaryEntry {
    var uuid: UUID = UUID()
    /// Начало дня (локальный календарь) — по нему группируем и фильтруем.
    var day: Date = Date()
    var loggedAt: Date = Date()
    var categoryRaw: String = MealCategory.breakfast.rawValue
    var name: String = ""
    var detail: String = ""
    /// Количество в г/мл.
    var amount: Double = 100
    var basisRaw: String = MeasureBasis.grams.rawValue
    var per100Data: Data = Data()
    /// Итоги записи (денормализовано для статистики).
    var kcal: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    /// "product" | "recipe" | "meal" | "quick"
    var sourceKindRaw: String = "product"
    var sourceID: UUID?
    /// Общий идентификатор для записей, добавленных одним сохранённым приёмом пищи.
    var groupID: UUID?

    init(day: Date, category: MealCategory, name: String, detail: String = "", amount: Double, basis: MeasureBasis,
         per100: NutritionFacts, sourceKind: String, sourceID: UUID?, groupID: UUID? = nil, loggedAt: Date = Date()) {
        self.uuid = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        self.loggedAt = loggedAt
        self.categoryRaw = category.rawValue
        self.name = name
        self.detail = detail
        self.amount = amount
        self.basisRaw = basis.rawValue
        self.sourceKindRaw = sourceKind
        self.sourceID = sourceID
        self.groupID = groupID
        self.per100Data = Data()
        self.per100 = per100
    }

    var category: MealCategory {
        get { MealCategory(rawValue: categoryRaw) ?? .snack }
        set { categoryRaw = newValue.rawValue }
    }

    var basis: MeasureBasis { MeasureBasis(rawValue: basisRaw) ?? .grams }

    var per100: NutritionFacts {
        get { (try? JSONDecoder().decode(NutritionFacts.self, from: per100Data)) ?? NutritionFacts() }
        set {
            per100Data = (try? JSONEncoder().encode(newValue)) ?? Data()
            recalculateTotals()
        }
    }

    /// Полные итоги записи (все поля).
    var totals: NutritionFacts { per100.forAmount(amount) }

    func recalculateTotals() {
        let t = totals
        kcal = t.kcal
        protein = t.proteinValue
        fat = t.fatValue
        carbs = t.carbsValue
    }

    var amountLabel: String {
        "\(NutrientFormatter.grams(amount)) \(basis.unitSymbol)"
    }

    var summary: EntrySummary {
        EntrySummary(day: day, category: category, facts: totals)
    }
}
