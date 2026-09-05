import XCTest
@testable import FoodyCore

final class NutritionFactsTests: XCTestCase {
    func testScalingAndAmount() {
        let per100 = NutritionFacts(energyKcal: 250, fat: 10, carbohydrates: 30, sugars: 5, fiber: 2, protein: 8, salt: 1.2)
        let portion = per100.forAmount(50)
        XCTAssertEqual(portion.kcal, 125, accuracy: 0.001)
        XCTAssertEqual(portion.fat ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(portion.salt ?? 0, 0.6, accuracy: 0.001)
        XCTAssertNil(portion.saturatedFat, "nil остаётся nil, а не превращается в 0")
    }

    func testAdditionKeepsNilWhenBothNil() {
        let a = NutritionFacts(energyKcal: 100, protein: 5)
        let b = NutritionFacts(energyKcal: 50, fat: 3)
        let s = a + b
        XCTAssertEqual(s.energyKcal, 150)
        XCTAssertEqual(s.protein, 5)
        XCTAssertEqual(s.fat, 3)
        XCTAssertNil(s.carbohydrates)
        XCTAssertNil(s.fiber)
    }

    func testKcalFallbacks() {
        XCTAssertEqual(NutritionFacts(energyKJ: 418.4).kcal, 100, accuracy: 0.01)
        let macrosOnly = NutritionFacts(fat: 10, carbohydrates: 20, protein: 5)
        XCTAssertEqual(macrosOnly.kcal, 10 * 9 + 20 * 4 + 5 * 4, accuracy: 0.001)
        XCTAssertEqual(NutritionFacts().kcal, 0)
        XCTAssertEqual(NutritionFacts(energyKcal: 100).kJ ?? 0, 418.4, accuracy: 0.01)
    }

    func testSaltSodiumConversions() {
        XCTAssertEqual(NutritionFacts(sodiumMg: 400).saltResolved ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(NutritionFacts(salt: 1.0).sodiumResolvedMg ?? 0, 400, accuracy: 0.0001)
        XCTAssertEqual(NutritionFacts(salt: 0.5, sodiumMg: 999).saltResolved, 0.5, "явно указанная соль важнее")
    }

    func testMicronutrientsSumAndNRV() {
        let a = NutritionFacts(micronutrients: [MicronutrientValue(key: "vitamin_c", amount: 40, unit: "мг")])
        let b = NutritionFacts(micronutrients: [MicronutrientValue(key: "vitamin_c", amount: 40, unit: "mg"),
                                                MicronutrientValue(key: "iron", amount: 7, unit: "mg")])
        let s = a + b
        XCTAssertEqual(s.micronutrients.count, 2)
        // единицы записаны по-разному («мг» и «mg»), суммируем только при совпадении — берём первое значение
        let vitC = s.micronutrients.first { $0.key == "vitamin_c" }
        XCTAssertNotNil(vitC)
        let iron = MicronutrientValue(key: "iron", amount: 7, unit: "mg")
        XCTAssertEqual(iron.nrvFraction ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(MicronutrientValue(key: "vitamin_d", amount: 2.5, unit: "µg").nrvFraction ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(Micronutrient(looseName: "Vitamin B1"), .thiamin)
        XCTAssertEqual(Micronutrient(looseName: "folate"), .folicAcid)
    }

    func testCodableRoundTripAndTolerantDecoding() throws {
        let facts = NutritionFacts(energyKcal: 372, energyKJ: 1560, fat: 7, saturatedFat: 1.3, carbohydrates: 58.7,
                                   sugars: 0.7, fiber: 10, protein: 13.5, salt: 0.01,
                                   micronutrients: [MicronutrientValue(key: "iron", amount: 4.2, unit: "мг")])
        let data = try JSONEncoder().encode(facts)
        let back = try JSONDecoder().decode(NutritionFacts.self, from: data)
        XCTAssertEqual(back, facts)
        let partial = try JSONDecoder().decode(NutritionFacts.self, from: Data(#"{"energyKcal": 10}"#.utf8))
        XCTAssertEqual(partial.energyKcal, 10)
        XCTAssertTrue(partial.micronutrients.isEmpty)
    }

    func testRounding() {
        let f = NutritionFacts(energyKcal: 123.6, fat: 1.26, salt: 0.126).rounded()
        XCTAssertEqual(f.energyKcal, 124)
        XCTAssertEqual(f.fat, 1.3)
        XCTAssertEqual(f.salt, 0.13)
    }

    func testFormatter() {
        XCTAssertEqual(NutrientFormatter.parse("12,5"), 12.5)
        XCTAssertEqual(NutrientFormatter.parse(" 0.8 "), 0.8)
        XCTAssertEqual(NutrientFormatter.parse("<0,5"), 0.5)
        XCTAssertNil(NutrientFormatter.parse(""))
        XCTAssertEqual(NutrientFormatter.grams(12.5), "12,5")
        XCTAssertEqual(NutrientFormatter.kcal(1234.4), "1 234")
        XCTAssertEqual(NutrientFormatter.percent(0.856), "86 %")
    }
}
