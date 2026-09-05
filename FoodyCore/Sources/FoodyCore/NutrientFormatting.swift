import Foundation

/// Форматирование чисел для интерфейса (русская запись: запятая как десятичный разделитель,
/// неразрывный пробел между разрядами). Реализовано вручную, чтобы результат не зависел от
/// версии ICU/локали платформы и одинаково работал на iOS и Linux (тесты).
public enum NutrientFormatter {
    public static let groupingSeparator = "\u{00A0}"

    /// «1 234» — калории (целое число с разрядами).
    public static func kcal(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let n = Int(value.rounded())
        let digits = Array(String(abs(n)))
        var grouped: [Character] = []
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { grouped.append(contentsOf: groupingSeparator) }
            grouped.append(ch)
        }
        return (n < 0 ? "-" : "") + String(grouped.reversed())
    }

    /// «12,5» — граммы с одним знаком (без хвостовых нулей).
    public static func grams(_ value: Double) -> String { fixed(value, digits: 1) }

    /// «0,35» — соль и малые величины (до двух знаков).
    public static func precise(_ value: Double) -> String { fixed(value, digits: 2) }

    /// Универсальное: целые для больших значений, иначе 1 знак; для значений < 1 — 2 знака.
    public static func auto(_ value: Double) -> String {
        if abs(value) < 1 && value != 0 { return precise(value) }
        if abs(value) >= 100 { return kcal(value) }
        return grams(value)
    }

    /// Значение с единицей: «12,5 г», «250 ккал».
    public static func withUnit(_ value: Double, unit: String) -> String {
        unit == "ккал" ? "\(kcal(value)) ккал" : "\(auto(value)) \(unit)"
    }

    /// Разбор пользовательского ввода: принимает и запятую, и точку, пробелы между разрядами; пустая строка → nil.
    public static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.hasPrefix("<") { return Double(cleaned.dropFirst()) }
        return Double(cleaned)
    }

    /// Процент «86 %».
    public static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite else { return "—" }
        return "\(Int((fraction * 100).rounded())) %"
    }

    private static func fixed(_ value: Double, digits: Int) -> String {
        guard value.isFinite else { return "—" }
        var s = String(format: "%.\(digits)f", value)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        if s == "-0" { s = "0" }
        return s.replacingOccurrences(of: ".", with: ",")
    }
}
