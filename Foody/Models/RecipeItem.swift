import Foundation
import FoodyCore

/// Позиция состава (ингредиент рецепта или компонент сохранённого приёма пищи).
/// Хранит снимок значений продукта, чтобы удаление/правка продукта не ломала рецепт.
struct RecipeItem: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var productID: UUID?
    var name: String
    var amount: Double            // г или мл
    var basisRaw: String = MeasureBasis.grams.rawValue
    var per100: NutritionFacts

    var basis: MeasureBasis { MeasureBasis(rawValue: basisRaw) ?? .grams }
    var nutrients: NutritionFacts { per100.forAmount(amount) }
    var input: IngredientInput { IngredientInput(amount: amount, per100: per100) }

    init(product: Product, amount: Double) {
        self.id = UUID()
        self.productID = product.uuid
        self.name = product.brand.isEmpty ? product.name : "\(product.name) (\(product.brand))"
        self.amount = amount
        self.basisRaw = product.basisRaw
        self.per100 = product.facts
    }

    init(id: UUID = UUID(), productID: UUID?, name: String, amount: Double, basis: MeasureBasis, per100: NutritionFacts) {
        self.id = id
        self.productID = productID
        self.name = name
        self.amount = amount
        self.basisRaw = basis.rawValue
        self.per100 = per100
    }

    static func encode(_ items: [RecipeItem]) -> Data {
        (try? JSONEncoder().encode(items)) ?? Data()
    }

    static func decode(_ data: Data) -> [RecipeItem] {
        (try? JSONDecoder().decode([RecipeItem].self, from: data)) ?? []
    }
}
