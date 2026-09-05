import Foundation

/// На что нормированы значения продукта: на 100 г или на 100 мл.
public enum MeasureBasis: String, Codable, CaseIterable, Hashable, Sendable {
    case grams = "g"
    case milliliters = "ml"

    /// Короткое обозначение единицы («г» / «мл»).
    public var unitSymbol: String {
        switch self {
        case .grams: return "г"
        case .milliliters: return "мл"
        }
    }

    /// Подпись «на 100 г» / «на 100 мл».
    public var per100Title: String { "на 100 \(unitSymbol)" }
}
