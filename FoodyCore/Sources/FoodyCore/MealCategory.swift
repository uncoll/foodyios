import Foundation

/// Приём пищи — категория группировки записей дневника.
public enum MealCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .breakfast: return "Завтрак"
        case .lunch: return "Обед"
        case .dinner: return "Ужин"
        case .snack: return "Перекусы"
        }
    }

    /// SF Symbol для иконки категории.
    public var symbolName: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "takeoutbag.and.cup.and.straw"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .snack: return 3
        }
    }

    /// Категория по умолчанию для текущего часа: до 11 — завтрак, до 16 — обед, до 21 — ужин, иначе перекус.
    public static func suggested(forHour hour: Int) -> MealCategory {
        switch hour {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
    }

    public static func suggested(for date: Date, calendar: Calendar = .current) -> MealCategory {
        suggested(forHour: calendar.component(.hour, from: date))
    }
}
