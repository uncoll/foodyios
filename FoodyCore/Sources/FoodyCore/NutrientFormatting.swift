import Foundation

/// Форматирование чисел для интерфейса (русская локаль: запятая как разделитель).
public enum NutrientFormatter {
    private static let locale = Locale(identifier: "ru_RU")

    private static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()

    private static let oneDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.usesGroupingSeparator = false
        return f
    }()

    private static let twoDecimals: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = false
        return f
    }()

    /// «1 234» — калории.
    public static func kcal(_ value: Double) -> String {
        integer.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    /// «12,5» — граммы с одним знаком.
    public static func grams(_ value: Double) -> String {
        oneDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    /// «0,35» — соль и малые величины.
    public static func precise(_ value: Double) -> String {
        twoDecimals.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// Универсальное: целые для ккал, иначе 1 знак; для значений < 1 — 2 знака.
    public static func auto(_ value: Double) -> String {
        if abs(value) < 1 && value != 0 { return precise(value) }
        if abs(value) >= 100 { return kcal(value) }
        return grams(value)
    }

    /// Значение с единицей: «12,5 г», «250 ккал».
    public static func withUnit(_ value: Double, unit: String) -> String {
        unit == "ккал" ? "\(kcal(value)) ккал" : "\(auto(value)) \(unit)"
    }

    /// Разбор пользовательского ввода: принимает и запятую, и точку; пустая строка → nil.
    public static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.hasPrefix("<") { return Double(cleaned.dropFirst()) }
        return Double(cleaned)
    }

    /// Процент «85 %».
    public static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) %"
    }
}
