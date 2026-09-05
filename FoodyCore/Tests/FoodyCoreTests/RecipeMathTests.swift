import XCTest
@testable import FoodyCore

final class RecipeMathTests: XCTestCase {
    // Гречка 200 г сухой (343 ккал/100) + вода 400 г; после варки вес 560 г; порция 200 г.
    func testRecipePer100ByFinalWeightAndPortion() {
        let buckwheat = NutritionFacts(energyKcal: 343, fat: 3.4, carbohydrates: 71.5, fiber: 10, protein: 13.3, salt: 0)
        let water = NutritionFacts(energyKcal: 0, fat: 0, carbohydrates: 0, protein: 0)
        let items = [IngredientInput(amount: 200, per100: buckwheat), IngredientInput(amount: 400, per100: water)]
        let s = RecipeMath.summary(items: items, finalWeight: 560, portionWeight: 200)
        XCTAssertEqual(s.rawWeight, 600)
        XCTAssertEqual(s.finalWeight, 560)
        XCTAssertEqual(s.total.kcal, 686, accuracy: 0.001)
        XCTAssertEqual(s.per100.kcal, 686 / 5.6, accuracy: 0.001)
        XCTAssertEqual(s.per100.protein ?? 0, 26.6 / 5.6, accuracy: 0.001)
        XCTAssertEqual(s.perPortion.kcal, 686 / 5.6 * 2, accuracy: 0.001)
        XCTAssertEqual(s.portionsCount, 2.8, accuracy: 0.001)
    }

    func testFallbackToRawWeightWhenFinalWeightMissing() {
        let items = [IngredientInput(amount: 100, per100: NutritionFacts(kcal: 100, protein: 10, fat: 5, carbs: 20)),
                     IngredientInput(amount: 100, per100: NutritionFacts(kcal: 300, protein: 0, fat: 30, carbs: 10))]
        let s = RecipeMath.summary(items: items, finalWeight: nil, portionWeight: nil)
        XCTAssertEqual(s.finalWeight, 200)
        XCTAssertEqual(s.per100.kcal, 200, accuracy: 0.001)
        XCTAssertEqual(s.portionWeight, 200, "без заданной порции порция = всё блюдо")
        XCTAssertEqual(s.portionsCount, 1, accuracy: 0.001)
    }

    func testEmptyRecipe() {
        let s = RecipeMath.summary(items: [], finalWeight: nil, portionWeight: 100)
        XCTAssertEqual(s.per100, .empty)
        XCTAssertEqual(s.perPortion.kcal, 0)
    }
}
