import Foundation

/// Ответ модели по схеме `LabelParseSpec.schemaJSON` (ключи — snake_case, как в схеме).
public struct LabelParseResult: Codable, Equatable, Sendable {
    public var productName: String?
    public var brand: String?
    public var basis: String                 // per_100g | per_100ml
    public var servingSizeG: Double?
    public var servingDescription: String?
    public var energyKcal: Double?
    public var energyKj: Double?
    public var fatG: Double?
    public var saturatedFatG: Double?
    public var monounsaturatedFatG: Double?
    public var polyunsaturatedFatG: Double?
    public var transFatG: Double?
    public var cholesterolMg: Double?
    public var carbohydratesG: Double?
    public var sugarsG: Double?
    public var polyolsG: Double?
    public var starchG: Double?
    public var fiberG: Double?
    public var proteinG: Double?
    public var saltG: Double?
    public var sodiumMg: Double?
    public var alcoholG: Double?
    public var micronutrients: [Micro]
    public var labelLanguage: String?
    public var valuesSource: String?         // per_100_column | converted_from_serving | unclear
    public var notes: String?
    public var confidence: String?           // high | medium | low

    public struct Micro: Codable, Equatable, Sendable {
        public var name: String
        public var amount: Double
        public var unit: String

        public init(name: String, amount: Double, unit: String) {
            self.name = name
            self.amount = amount
            self.unit = unit
        }
    }

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brand
        case basis
        case servingSizeG = "serving_size_g"
        case servingDescription = "serving_description"
        case energyKcal = "energy_kcal"
        case energyKj = "energy_kj"
        case fatG = "fat_g"
        case saturatedFatG = "saturated_fat_g"
        case monounsaturatedFatG = "monounsaturated_fat_g"
        case polyunsaturatedFatG = "polyunsaturated_fat_g"
        case transFatG = "trans_fat_g"
        case cholesterolMg = "cholesterol_mg"
        case carbohydratesG = "carbohydrates_g"
        case sugarsG = "sugars_g"
        case polyolsG = "polyols_g"
        case starchG = "starch_g"
        case fiberG = "fiber_g"
        case proteinG = "protein_g"
        case saltG = "salt_g"
        case sodiumMg = "sodium_mg"
        case alcoholG = "alcohol_g"
        case micronutrients
        case labelLanguage = "label_language"
        case valuesSource = "values_source"
        case notes
        case confidence
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productName = try c.decodeIfPresent(String.self, forKey: .productName)
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        basis = try c.decodeIfPresent(String.self, forKey: .basis) ?? "per_100g"
        servingSizeG = try Self.number(c, .servingSizeG)
        servingDescription = try c.decodeIfPresent(String.self, forKey: .servingDescription)
        energyKcal = try Self.number(c, .energyKcal)
        energyKj = try Self.number(c, .energyKj)
        fatG = try Self.number(c, .fatG)
        saturatedFatG = try Self.number(c, .saturatedFatG)
        monounsaturatedFatG = try Self.number(c, .monounsaturatedFatG)
        polyunsaturatedFatG = try Self.number(c, .polyunsaturatedFatG)
        transFatG = try Self.number(c, .transFatG)
        cholesterolMg = try Self.number(c, .cholesterolMg)
        carbohydratesG = try Self.number(c, .carbohydratesG)
        sugarsG = try Self.number(c, .sugarsG)
        polyolsG = try Self.number(c, .polyolsG)
        starchG = try Self.number(c, .starchG)
        fiberG = try Self.number(c, .fiberG)
        proteinG = try Self.number(c, .proteinG)
        saltG = try Self.number(c, .saltG)
        sodiumMg = try Self.number(c, .sodiumMg)
        alcoholG = try Self.number(c, .alcoholG)
        micronutrients = try c.decodeIfPresent([Micro].self, forKey: .micronutrients) ?? []
        labelLanguage = try c.decodeIfPresent(String.self, forKey: .labelLanguage)
        valuesSource = try c.decodeIfPresent(String.self, forKey: .valuesSource)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence)
    }

    /// Число, терпимое к строкам вида "12,5" / "<0.5" (на случай нестрогого ответа).
    private static func number(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return NutrientFormatter.parse(s) }
        return nil
    }

    public init(basis: String = "per_100g") {
        self.basis = basis
        self.micronutrients = []
    }

    /// Разбор JSON-текста ответа модели.
    public static func decode(jsonText: String) throws -> LabelParseResult {
        let trimmed = Self.stripCodeFence(jsonText)
        return try JSONDecoder().decode(LabelParseResult.self, from: Data(trimmed.utf8))
    }

    static func stripCodeFence(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") { t = String(t[t.index(after: firstNewline)...]) }
            if t.hasSuffix("```") { t = String(t.dropLast(3)) }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Преобразование в доменные типы

    public var measureBasis: MeasureBasis { basis == "per_100ml" ? .milliliters : .grams }

    public var nutritionFacts: NutritionFacts {
        NutritionFacts(
            energyKcal: energyKcal, energyKJ: energyKj, fat: fatG, saturatedFat: saturatedFatG,
            monounsaturatedFat: monounsaturatedFatG, polyunsaturatedFat: polyunsaturatedFatG, transFat: transFatG,
            cholesterolMg: cholesterolMg, carbohydrates: carbohydratesG, sugars: sugarsG, polyols: polyolsG,
            starch: starchG, fiber: fiberG, protein: proteinG, salt: saltG, sodiumMg: sodiumMg, alcohol: alcoholG,
            micronutrients: micronutrients.map { m in
                MicronutrientValue(key: Micronutrient(looseName: m.name)?.rawValue ?? m.name, amount: m.amount, unit: m.unit)
            }
        )
    }

    /// Есть ли хотя бы одно из основных значений.
    public var hasMainValues: Bool {
        energyKcal != nil || energyKj != nil || fatG != nil || carbohydratesG != nil || proteinG != nil
    }

    /// Человекочитаемое описание уверенности/источника для баннера в форме.
    public var reviewHint: String {
        var parts: [String] = []
        switch confidence {
        case "high": parts.append("Уверенность модели высокая")
        case "medium": parts.append("Уверенность средняя — проверьте цифры")
        case "low": parts.append("Низкая уверенность — проверьте всё внимательно")
        default: break
        }
        if valuesSource == "converted_from_serving" { parts.append("значения пересчитаны из порции") }
        if valuesSource == "unclear" { parts.append("не удалось определить значения на 100 г/мл") }
        if let n = notes, !n.isEmpty { parts.append(n) }
        return parts.joined(separator: ". ")
    }
}
