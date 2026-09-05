import SwiftUI
import FoodyCore

/// Цвета и стили интерфейса: спокойная минималистичная палитра, работает в светлой и тёмной теме.
enum Theme {
    static let accent = Color(red: 0.12, green: 0.66, blue: 0.48)        // изумрудный — калории/акцент
    static let protein = Color(red: 0.31, green: 0.55, blue: 0.97)       // синий
    static let fat = Color(red: 0.96, green: 0.70, blue: 0.14)           // янтарный
    static let carbs = Color(red: 0.95, green: 0.43, blue: 0.43)         // коралловый
    static let over = Color(red: 0.90, green: 0.30, blue: 0.30)
    static let under = Color(red: 0.36, green: 0.58, blue: 0.94)
    static let card = Color(.secondarySystemGroupedBackground)
    static let background = Color(.systemGroupedBackground)

    static func color(for macro: Macro) -> Color {
        switch macro {
        case .kcal: return accent
        case .protein: return protein
        case .fat: return fat
        case .carbs: return carbs
        }
    }

    static func color(for balance: Balance) -> Color {
        switch balance {
        case .over: return over
        case .under: return under
        case .onTarget: return accent
        }
    }

    static func color(for category: MealCategory) -> Color {
        switch category {
        case .breakfast: return Color(red: 0.98, green: 0.62, blue: 0.24)
        case .lunch: return Color(red: 0.20, green: 0.68, blue: 0.62)
        case .dinner: return Color(red: 0.45, green: 0.44, blue: 0.90)
        case .snack: return Color(red: 0.85, green: 0.48, blue: 0.70)
        }
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// Крупная цифра в скруглённом шрифте — фирменный стиль показателей.
struct BigNumber: View {
    let value: String
    var unit: String? = nil
    var color: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            if let unit {
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
