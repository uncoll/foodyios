import Foundation

/// Дневные цели по КБЖУ (и необязательные лимиты).
public struct DailyTargets: Codable, Equatable, Hashable, Sendable {
    public var kcal: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double
    /// Необязательные ориентиры: клетчатка (минимум), сахара / насыщенные жиры / соль (максимум).
    public var fiberMin: Double?
    public var sugarsMax: Double?
    public var saturatedFatMax: Double?
    public var saltMax: Double?

    public init(kcal: Double, protein: Double, fat: Double, carbs: Double,
                fiberMin: Double? = nil, sugarsMax: Double? = nil, saturatedFatMax: Double? = nil, saltMax: Double? = nil) {
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.fiberMin = fiberMin
        self.sugarsMax = sugarsMax
        self.saturatedFatMax = saturatedFatMax
        self.saltMax = saltMax
    }

    /// Разумные значения по умолчанию (≈ взрослый со средней активностью).
    public static let standard = DailyTargets(kcal: 2000, protein: 110, fat: 70, carbs: 230, fiberMin: 25, sugarsMax: 50,
                                              saturatedFatMax: 22, saltMax: 6)

    public func value(for macro: Macro) -> Double {
        switch macro {
        case .kcal: return kcal
        case .protein: return protein
        case .fat: return fat
        case .carbs: return carbs
        }
    }

    /// Калорийность, соответствующая заданным граммам Б/Ж/У (4/9/4).
    public var kcalFromMacros: Double { protein * 4 + fat * 9 + carbs * 4 }

    /// Цели, умноженные на число дней (для недели/месяца).
    public func multiplied(by days: Double) -> DailyTargets {
        DailyTargets(kcal: kcal * days, protein: protein * days, fat: fat * days, carbs: carbs * days,
                     fiberMin: fiberMin.map { $0 * days }, sugarsMax: sugarsMax.map { $0 * days },
                     saturatedFatMax: saturatedFatMax.map { $0 * days }, saltMax: saltMax.map { $0 * days })
    }

    public static func + (lhs: DailyTargets, rhs: DailyTargets) -> DailyTargets {
        func a(_ x: Double?, _ y: Double?) -> Double? {
            if x == nil && y == nil { return nil }
            return (x ?? 0) + (y ?? 0)
        }
        return DailyTargets(kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein, fat: lhs.fat + rhs.fat,
                            carbs: lhs.carbs + rhs.carbs, fiberMin: a(lhs.fiberMin, rhs.fiberMin),
                            sugarsMax: a(lhs.sugarsMax, rhs.sugarsMax), saturatedFatMax: a(lhs.saturatedFatMax, rhs.saturatedFatMax),
                            saltMax: a(lhs.saltMax, rhs.saltMax))
    }
}

/// Калькулятор рекомендуемой калорийности (Миффлин — Сан Жеор) и раскладки макронутриентов.
public enum TargetCalculator {
    public enum Sex: String, CaseIterable, Codable, Sendable {
        case male, female
        public var title: String { self == .male ? "Мужской" : "Женский" }
    }

    public enum Activity: String, CaseIterable, Codable, Sendable {
        case sedentary, light, moderate, active, veryActive

        public var factor: Double {
            switch self {
            case .sedentary: return 1.2
            case .light: return 1.375
            case .moderate: return 1.55
            case .active: return 1.725
            case .veryActive: return 1.9
            }
        }

        public var title: String {
            switch self {
            case .sedentary: return "Сидячий образ жизни"
            case .light: return "Лёгкая активность (1–3 тренировки в неделю)"
            case .moderate: return "Средняя (3–5 тренировок)"
            case .active: return "Высокая (6–7 тренировок)"
            case .veryActive: return "Очень высокая (тяжёлая работа, 2 тренировки в день)"
            }
        }
    }

    public enum Goal: String, CaseIterable, Codable, Sendable {
        case lose, maintain, gain

        /// Поправка к поддерживающей калорийности.
        public var kcalDelta: Double {
            switch self {
            case .lose: return -400
            case .maintain: return 0
            case .gain: return 300
            }
        }

        public var title: String {
            switch self {
            case .lose: return "Снижение веса"
            case .maintain: return "Поддержание"
            case .gain: return "Набор массы"
            }
        }
    }

    /// Базовый обмен по Миффлину — Сан Жеору.
    public static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    /// Дневные цели: калории = BMR × активность + поправка цели; белок 1,8 г/кг, жиры 0,9 г/кг, остальное — углеводы.
    public static func targets(sex: Sex, weightKg: Double, heightCm: Double, age: Int, activity: Activity, goal: Goal) -> DailyTargets {
        let kcal = max(1200, (bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age) * activity.factor + goal.kcalDelta).rounded())
        let protein = (weightKg * (goal == .lose ? 2.0 : 1.8)).rounded()
        let fat = (weightKg * 0.9).rounded()
        let carbs = max(50, ((kcal - protein * 4 - fat * 9) / 4).rounded())
        return DailyTargets(kcal: kcal, protein: protein, fat: fat, carbs: carbs, fiberMin: 25, sugarsMax: (kcal * 0.1 / 4).rounded(),
                            saturatedFatMax: (kcal * 0.1 / 9).rounded(), saltMax: 6)
    }
}
