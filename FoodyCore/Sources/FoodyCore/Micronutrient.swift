import Foundation

/// Витамины и минералы из Приложения XIII Регламента (ЕС) № 1169/2011 с референсными значениями (NRV).
public enum Micronutrient: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case vitaminA = "vitamin_a"
    case vitaminD = "vitamin_d"
    case vitaminE = "vitamin_e"
    case vitaminK = "vitamin_k"
    case vitaminC = "vitamin_c"
    case thiamin = "thiamin"
    case riboflavin = "riboflavin"
    case niacin = "niacin"
    case vitaminB6 = "vitamin_b6"
    case folicAcid = "folic_acid"
    case vitaminB12 = "vitamin_b12"
    case biotin = "biotin"
    case pantothenicAcid = "pantothenic_acid"
    case potassium = "potassium"
    case chloride = "chloride"
    case calcium = "calcium"
    case phosphorus = "phosphorus"
    case magnesium = "magnesium"
    case iron = "iron"
    case zinc = "zinc"
    case copper = "copper"
    case manganese = "manganese"
    case fluoride = "fluoride"
    case selenium = "selenium"
    case chromium = "chromium"
    case molybdenum = "molybdenum"
    case iodine = "iodine"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .vitaminA: return "Витамин A"
        case .vitaminD: return "Витамин D"
        case .vitaminE: return "Витамин E"
        case .vitaminK: return "Витамин K"
        case .vitaminC: return "Витамин C"
        case .thiamin: return "Тиамин (B1)"
        case .riboflavin: return "Рибофлавин (B2)"
        case .niacin: return "Ниацин (B3)"
        case .vitaminB6: return "Витамин B6"
        case .folicAcid: return "Фолиевая кислота"
        case .vitaminB12: return "Витамин B12"
        case .biotin: return "Биотин"
        case .pantothenicAcid: return "Пантотеновая кислота"
        case .potassium: return "Калий"
        case .chloride: return "Хлорид"
        case .calcium: return "Кальций"
        case .phosphorus: return "Фосфор"
        case .magnesium: return "Магний"
        case .iron: return "Железо"
        case .zinc: return "Цинк"
        case .copper: return "Медь"
        case .manganese: return "Марганец"
        case .fluoride: return "Фторид"
        case .selenium: return "Селен"
        case .chromium: return "Хром"
        case .molybdenum: return "Молибден"
        case .iodine: return "Йод"
        }
    }

    /// Единица, в которой значение принято указывать на этикетке.
    public var unit: String {
        switch self {
        case .vitaminA, .vitaminD, .vitaminK, .folicAcid, .vitaminB12, .biotin, .selenium, .chromium, .molybdenum, .iodine:
            return "мкг"
        default:
            return "мг"
        }
    }

    /// Референсное потребление (NRV) для взрослого в единице `unit`.
    public var nrv: Double {
        switch self {
        case .vitaminA: return 800
        case .vitaminD: return 5
        case .vitaminE: return 12
        case .vitaminK: return 75
        case .vitaminC: return 80
        case .thiamin: return 1.1
        case .riboflavin: return 1.4
        case .niacin: return 16
        case .vitaminB6: return 1.4
        case .folicAcid: return 200
        case .vitaminB12: return 2.5
        case .biotin: return 50
        case .pantothenicAcid: return 6
        case .potassium: return 2000
        case .chloride: return 800
        case .calcium: return 800
        case .phosphorus: return 700
        case .magnesium: return 375
        case .iron: return 14
        case .zinc: return 10
        case .copper: return 1
        case .manganese: return 2
        case .fluoride: return 3.5
        case .selenium: return 55
        case .chromium: return 40
        case .molybdenum: return 50
        case .iodine: return 150
        }
    }

    public var isVitamin: Bool {
        switch self {
        case .vitaminA, .vitaminD, .vitaminE, .vitaminK, .vitaminC, .thiamin, .riboflavin, .niacin, .vitaminB6,
             .folicAcid, .vitaminB12, .biotin, .pantothenicAcid:
            return true
        default:
            return false
        }
    }

    /// Пытается сопоставить произвольное имя (из ответа модели) с известным микронутриентом.
    public init?(looseName: String) {
        let key = looseName.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        if let exact = Micronutrient(rawValue: key) {
            self = exact
            return
        }
        let aliases: [String: Micronutrient] = [
            "vitamin_b1": .thiamin, "thiamine": .thiamin, "b1": .thiamin,
            "vitamin_b2": .riboflavin, "b2": .riboflavin,
            "vitamin_b3": .niacin, "b3": .niacin,
            "vitamin_b5": .pantothenicAcid, "pantothenic": .pantothenicAcid,
            "vitamin_b7": .biotin, "vitamin_b9": .folicAcid, "folate": .folicAcid, "folates": .folicAcid,
            "vitamin_b_12": .vitaminB12, "vitamin_b_6": .vitaminB6, "vitamine_c": .vitaminC, "vitamin_d3": .vitaminD,
            "kalium": .potassium, "calcio": .calcium, "calcium_mg": .calcium, "ferro": .iron, "hierro": .iron, "fer": .iron,
            "magnesio": .magnesium, "zink": .zinc, "zinco": .zinc, "iodo": .iodine, "iod": .iodine, "jod": .iodine,
            "phosphor": .phosphorus, "fosforo": .phosphorus, "selen": .selenium, "selenio": .selenium
        ]
        if let alias = aliases[key] {
            self = alias
            return
        }
        return nil
    }
}

/// Значение микронутриента на 100 г/мл, как напечатано на этикетке.
public struct MicronutrientValue: Codable, Equatable, Hashable, Sendable {
    /// Ключ (`Micronutrient.rawValue` для известных, произвольная строка для остальных).
    public var key: String
    public var amount: Double
    public var unit: String

    public init(key: String, amount: Double, unit: String) {
        self.key = key
        self.amount = amount
        self.unit = unit
    }

    public var known: Micronutrient? { Micronutrient(rawValue: key) ?? Micronutrient(looseName: key) }

    public var title: String { known?.title ?? key.replacingOccurrences(of: "_", with: " ").capitalized }

    /// Доля от референсного потребления (0.5 = 50 %), если единицы совпадают с NRV.
    public var nrvFraction: Double? {
        guard let k = known else { return nil }
        let normalizedUnit = unit.lowercased()
            .replacingOccurrences(of: "µg", with: "мкг").replacingOccurrences(of: "\u{03BC}g", with: "мкг").replacingOccurrences(of: "ug", with: "мкг")
            .replacingOccurrences(of: "mcg", with: "мкг").replacingOccurrences(of: "mg", with: "мг")
        var amountInNrvUnit = amount
        if normalizedUnit != k.unit {
            switch (normalizedUnit, k.unit) {
            case ("мг", "мкг"): amountInNrvUnit = amount * 1000
            case ("мкг", "мг"): amountInNrvUnit = amount / 1000
            case ("g", "мг"), ("г", "мг"): amountInNrvUnit = amount * 1000
            default: return nil
            }
        }
        return amountInNrvUnit / k.nrv
    }
}
