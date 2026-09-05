import Foundation

/// Пищевая ценность на 100 г / 100 мл (или суммарная — для записей дневника и рецептов).
/// Все поля опциональны: `nil` означает «не указано на этикетке», а не ноль.
public struct NutritionFacts: Codable, Equatable, Hashable, Sendable {
    public var energyKcal: Double?
    public var energyKJ: Double?
    public var fat: Double?
    public var saturatedFat: Double?
    public var monounsaturatedFat: Double?
    public var polyunsaturatedFat: Double?
    public var transFat: Double?
    public var cholesterolMg: Double?
    public var carbohydrates: Double?
    public var sugars: Double?
    public var polyols: Double?
    public var starch: Double?
    public var fiber: Double?
    public var protein: Double?
    public var salt: Double?
    public var sodiumMg: Double?
    public var alcohol: Double?
    public var micronutrients: [MicronutrientValue]

    public init(energyKcal: Double? = nil, energyKJ: Double? = nil,
                fat: Double? = nil, saturatedFat: Double? = nil, monounsaturatedFat: Double? = nil,
                polyunsaturatedFat: Double? = nil, transFat: Double? = nil, cholesterolMg: Double? = nil,
                carbohydrates: Double? = nil, sugars: Double? = nil, polyols: Double? = nil, starch: Double? = nil,
                fiber: Double? = nil, protein: Double? = nil, salt: Double? = nil, sodiumMg: Double? = nil,
                alcohol: Double? = nil, micronutrients: [MicronutrientValue] = []) {
        self.energyKcal = energyKcal
        self.energyKJ = energyKJ
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.monounsaturatedFat = monounsaturatedFat
        self.polyunsaturatedFat = polyunsaturatedFat
        self.transFat = transFat
        self.cholesterolMg = cholesterolMg
        self.carbohydrates = carbohydrates
        self.sugars = sugars
        self.polyols = polyols
        self.starch = starch
        self.fiber = fiber
        self.protein = protein
        self.salt = salt
        self.sodiumMg = sodiumMg
        self.alcohol = alcohol
        self.micronutrients = micronutrients
    }

    /// Быстрый конструктор для КБЖУ.
    public init(kcal: Double, protein: Double, fat: Double, carbs: Double) {
        self.init(energyKcal: kcal, fat: fat, carbohydrates: carbs, protein: protein)
    }

    public static let empty = NutritionFacts()

    // Декодирование терпимо к отсутствующим ключам (старые записи, ответы модели без части полей).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        energyKcal = try c.decodeIfPresent(Double.self, forKey: .energyKcal)
        energyKJ = try c.decodeIfPresent(Double.self, forKey: .energyKJ)
        fat = try c.decodeIfPresent(Double.self, forKey: .fat)
        saturatedFat = try c.decodeIfPresent(Double.self, forKey: .saturatedFat)
        monounsaturatedFat = try c.decodeIfPresent(Double.self, forKey: .monounsaturatedFat)
        polyunsaturatedFat = try c.decodeIfPresent(Double.self, forKey: .polyunsaturatedFat)
        transFat = try c.decodeIfPresent(Double.self, forKey: .transFat)
        cholesterolMg = try c.decodeIfPresent(Double.self, forKey: .cholesterolMg)
        carbohydrates = try c.decodeIfPresent(Double.self, forKey: .carbohydrates)
        sugars = try c.decodeIfPresent(Double.self, forKey: .sugars)
        polyols = try c.decodeIfPresent(Double.self, forKey: .polyols)
        starch = try c.decodeIfPresent(Double.self, forKey: .starch)
        fiber = try c.decodeIfPresent(Double.self, forKey: .fiber)
        protein = try c.decodeIfPresent(Double.self, forKey: .protein)
        salt = try c.decodeIfPresent(Double.self, forKey: .salt)
        sodiumMg = try c.decodeIfPresent(Double.self, forKey: .sodiumMg)
        alcohol = try c.decodeIfPresent(Double.self, forKey: .alcohol)
        micronutrients = try c.decodeIfPresent([MicronutrientValue].self, forKey: .micronutrients) ?? []
    }

    // MARK: - Производные значения

    /// Килокалории: из энергии, иначе из кДж, иначе оценка по макронутриентам (4/9/4, клетчатка 2, алкоголь 7).
    public var kcal: Double {
        if let k = energyKcal { return k }
        if let kj = energyKJ { return kj / 4.184 }
        return estimatedKcalFromMacros ?? 0
    }

    /// Килоджоули: из энергии, иначе из ккал.
    public var kJ: Double? {
        if let kj = energyKJ { return kj }
        if let k = energyKcal { return k * 4.184 }
        return nil
    }

    /// Расчётная калорийность по макронутриентам (коэффициенты Регламента 1169/2011, Приложение XIV).
    public var estimatedKcalFromMacros: Double? {
        guard protein != nil || fat != nil || carbohydrates != nil else { return nil }
        let available = (carbohydrates ?? 0) - (polyols ?? 0)
        return (protein ?? 0) * 4 + (fat ?? 0) * 9 + available * 4 + (polyols ?? 0) * 2.4
            + (fiber ?? 0) * 2 + (alcohol ?? 0) * 7
    }

    public var proteinValue: Double { protein ?? 0 }
    public var fatValue: Double { fat ?? 0 }
    public var carbsValue: Double { carbohydrates ?? 0 }

    /// Соль: указанная, иначе из натрия (соль = натрий × 2,5).
    public var saltResolved: Double? {
        if let s = salt { return s }
        if let na = sodiumMg { return na * 2.5 / 1000 }
        return nil
    }

    /// Натрий (мг): указанный, иначе из соли.
    public var sodiumResolvedMg: Double? {
        if let na = sodiumMg { return na }
        if let s = salt { return s / 2.5 * 1000 }
        return nil
    }

    /// Есть ли хоть одно заполненное значение.
    public var isEmpty: Bool {
        energyKcal == nil && energyKJ == nil && fat == nil && saturatedFat == nil && monounsaturatedFat == nil
            && polyunsaturatedFat == nil && transFat == nil && cholesterolMg == nil && carbohydrates == nil
            && sugars == nil && polyols == nil && starch == nil && fiber == nil && protein == nil
            && salt == nil && sodiumMg == nil && alcohol == nil && micronutrients.isEmpty
    }

    // MARK: - Арифметика

    /// Умножение всех значений на коэффициент (например, `amount / 100`).
    public func scaled(by factor: Double) -> NutritionFacts {
        func m(_ v: Double?) -> Double? { v.map { $0 * factor } }
        return NutritionFacts(
            energyKcal: m(energyKcal), energyKJ: m(energyKJ), fat: m(fat), saturatedFat: m(saturatedFat),
            monounsaturatedFat: m(monounsaturatedFat), polyunsaturatedFat: m(polyunsaturatedFat), transFat: m(transFat),
            cholesterolMg: m(cholesterolMg), carbohydrates: m(carbohydrates), sugars: m(sugars), polyols: m(polyols),
            starch: m(starch), fiber: m(fiber), protein: m(protein), salt: m(salt), sodiumMg: m(sodiumMg),
            alcohol: m(alcohol),
            micronutrients: micronutrients.map { MicronutrientValue(key: $0.key, amount: $0.amount * factor, unit: $0.unit) }
        )
    }

    /// Значения для указанного количества (г/мл), если `self` — значения на 100.
    public func forAmount(_ amount: Double) -> NutritionFacts { scaled(by: amount / 100) }

    /// Сложение: `nil + nil = nil`, `nil + x = x`.
    public static func + (lhs: NutritionFacts, rhs: NutritionFacts) -> NutritionFacts {
        func a(_ x: Double?, _ y: Double?) -> Double? {
            if x == nil && y == nil { return nil }
            return (x ?? 0) + (y ?? 0)
        }
        var micro: [String: MicronutrientValue] = [:]
        for v in lhs.micronutrients + rhs.micronutrients {
            if let existing = micro[v.key], existing.unit == v.unit {
                micro[v.key] = MicronutrientValue(key: v.key, amount: existing.amount + v.amount, unit: v.unit)
            } else if micro[v.key] == nil {
                micro[v.key] = v
            }
        }
        return NutritionFacts(
            energyKcal: a(lhs.energyKcal, rhs.energyKcal), energyKJ: a(lhs.energyKJ, rhs.energyKJ),
            fat: a(lhs.fat, rhs.fat), saturatedFat: a(lhs.saturatedFat, rhs.saturatedFat),
            monounsaturatedFat: a(lhs.monounsaturatedFat, rhs.monounsaturatedFat),
            polyunsaturatedFat: a(lhs.polyunsaturatedFat, rhs.polyunsaturatedFat), transFat: a(lhs.transFat, rhs.transFat),
            cholesterolMg: a(lhs.cholesterolMg, rhs.cholesterolMg), carbohydrates: a(lhs.carbohydrates, rhs.carbohydrates),
            sugars: a(lhs.sugars, rhs.sugars), polyols: a(lhs.polyols, rhs.polyols), starch: a(lhs.starch, rhs.starch),
            fiber: a(lhs.fiber, rhs.fiber), protein: a(lhs.protein, rhs.protein), salt: a(lhs.salt, rhs.salt),
            sodiumMg: a(lhs.sodiumMg, rhs.sodiumMg), alcohol: a(lhs.alcohol, rhs.alcohol),
            micronutrients: micro.values.sorted { $0.key < $1.key }
        )
    }

    public static func sum(_ items: [NutritionFacts]) -> NutritionFacts {
        items.reduce(NutritionFacts.empty, +)
    }

    /// Округление до разумной точности для отображения/хранения (ккал — целые, остальное — 0,1; соль — 0,01).
    public func rounded() -> NutritionFacts {
        func r1(_ v: Double?) -> Double? { v.map { ($0 * 10).rounded() / 10 } }
        func r2(_ v: Double?) -> Double? { v.map { ($0 * 100).rounded() / 100 } }
        var copy = self
        copy.energyKcal = energyKcal.map { $0.rounded() }
        copy.energyKJ = energyKJ.map { $0.rounded() }
        copy.fat = r1(fat); copy.saturatedFat = r1(saturatedFat); copy.monounsaturatedFat = r1(monounsaturatedFat)
        copy.polyunsaturatedFat = r1(polyunsaturatedFat); copy.transFat = r1(transFat)
        copy.cholesterolMg = r1(cholesterolMg); copy.carbohydrates = r1(carbohydrates); copy.sugars = r1(sugars)
        copy.polyols = r1(polyols); copy.starch = r1(starch); copy.fiber = r1(fiber); copy.protein = r1(protein)
        copy.salt = r2(salt); copy.sodiumMg = r1(sodiumMg); copy.alcohol = r1(alcohol)
        return copy
    }
}

/// Один из четырёх основных показателей — для целей, статистики и раскраски интерфейса.
public enum Macro: String, CaseIterable, Identifiable, Codable, Sendable {
    case kcal, protein, fat, carbs

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .kcal: return "Калории"
        case .protein: return "Белки"
        case .fat: return "Жиры"
        case .carbs: return "Углеводы"
        }
    }

    public var shortTitle: String {
        switch self {
        case .kcal: return "ккал"
        case .protein: return "Б"
        case .fat: return "Ж"
        case .carbs: return "У"
        }
    }

    public var unit: String { self == .kcal ? "ккал" : "г" }

    public func value(in facts: NutritionFacts) -> Double {
        switch self {
        case .kcal: return facts.kcal
        case .protein: return facts.proteinValue
        case .fat: return facts.fatValue
        case .carbs: return facts.carbsValue
        }
    }
}
