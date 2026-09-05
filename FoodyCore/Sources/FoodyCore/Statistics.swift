import Foundation

/// Минимальное представление записи дневника для статистики.
public struct EntrySummary: Equatable, Sendable {
    public var day: Date            // начало дня (локальный календарь)
    public var category: MealCategory
    public var facts: NutritionFacts   // суммарно для записи (уже умножено на количество)

    public init(day: Date, category: MealCategory, facts: NutritionFacts) {
        self.day = day
        self.category = category
        self.facts = facts
    }
}

/// Цели, действующие начиная с даты `effectiveFrom` (история изменений целей).
public struct TargetSnapshot: Equatable, Sendable {
    public var effectiveFrom: Date
    public var targets: DailyTargets

    public init(effectiveFrom: Date, targets: DailyTargets) {
        self.effectiveFrom = effectiveFrom
        self.targets = targets
    }
}

public enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .day: return "День"
        case .week: return "Неделя"
        case .month: return "Месяц"
        }
    }
}

/// Итоги одного дня.
public struct DayTotals: Identifiable, Equatable, Sendable {
    public var day: Date
    public var facts: NutritionFacts
    public var byCategory: [MealCategory: NutritionFacts]
    public var targets: DailyTargets?
    public var entryCount: Int

    public init(day: Date, facts: NutritionFacts, byCategory: [MealCategory: NutritionFacts], targets: DailyTargets?, entryCount: Int) {
        self.day = day
        self.facts = facts
        self.byCategory = byCategory
        self.targets = targets
        self.entryCount = entryCount
    }

    public var id: Date { day }
    public var hasEntries: Bool { entryCount > 0 }

    /// Разница «факт − цель» по показателю (nil, если целей нет).
    public func delta(_ macro: Macro) -> Double? {
        guard let t = targets else { return nil }
        return macro.value(in: facts) - t.value(for: macro)
    }

    /// Доля от цели (1.0 = 100 %).
    public func progress(_ macro: Macro) -> Double? {
        guard let t = targets, t.value(for: macro) > 0 else { return nil }
        return macro.value(in: facts) / t.value(for: macro)
    }
}

/// Оценка «перебор / недобор / в норме» по калориям или макронутриенту.
public enum Balance: String, Sendable {
    case under, onTarget, over

    public var title: String {
        switch self {
        case .under: return "Недобор"
        case .onTarget: return "В норме"
        case .over: return "Перебор"
        }
    }

    /// Допуск ±5 % считаем нормой.
    public static func evaluate(actual: Double, target: Double, tolerance: Double = 0.05) -> Balance {
        guard target > 0 else { return .onTarget }
        let ratio = actual / target
        if ratio > 1 + tolerance { return .over }
        if ratio < 1 - tolerance { return .under }
        return .onTarget
    }
}

/// Статистика за период (день / неделя / месяц).
public struct PeriodStats: Equatable, Sendable {
    public var period: StatsPeriod
    public var days: [DayTotals]             // все дни периода, включая пустые
    public var total: NutritionFacts         // сумма за учтённые дни
    public var byCategory: [MealCategory: NutritionFacts]
    public var loggedDays: Int
    /// Сумма целей за учтённые дни (дни с записями); nil, если целей не было.
    public var targetSum: DailyTargets?

    public init(period: StatsPeriod, days: [DayTotals], total: NutritionFacts, byCategory: [MealCategory: NutritionFacts],
                loggedDays: Int, targetSum: DailyTargets?) {
        self.period = period
        self.days = days
        self.total = total
        self.byCategory = byCategory
        self.loggedDays = loggedDays
        self.targetSum = targetSum
    }

    /// Среднее в день по учтённым дням.
    public var averagePerLoggedDay: NutritionFacts {
        loggedDays > 0 ? total.scaled(by: 1 / Double(loggedDays)) : .empty
    }

    /// Средняя цель в день за учтённые дни.
    public var averageTarget: DailyTargets? {
        guard let t = targetSum, loggedDays > 0 else { return nil }
        return t.multiplied(by: 1 / Double(loggedDays))
    }

    /// «Факт − цель» за период по показателю.
    public func delta(_ macro: Macro) -> Double? {
        guard let t = targetSum else { return nil }
        return macro.value(in: total) - t.value(for: macro)
    }

    public func progress(_ macro: Macro) -> Double? {
        guard let t = targetSum, t.value(for: macro) > 0 else { return nil }
        return macro.value(in: total) / t.value(for: macro)
    }

    public func balance(_ macro: Macro) -> Balance? {
        guard let t = targetSum else { return nil }
        return Balance.evaluate(actual: macro.value(in: total), target: t.value(for: macro))
    }

    /// Сколько учтённых дней с перебором / недобором калорий.
    public var daysOverKcal: Int { days.filter { $0.hasEntries && ($0.delta(.kcal) ?? 0) > 0 && balanceOf($0) == .over }.count }
    public var daysUnderKcal: Int { days.filter { $0.hasEntries && balanceOf($0) == .under }.count }

    private func balanceOf(_ d: DayTotals) -> Balance? {
        guard let t = d.targets else { return nil }
        return Balance.evaluate(actual: d.facts.kcal, target: t.kcal)
    }

    /// Доля категории в калориях периода (0…1).
    public func categoryShare(_ category: MealCategory) -> Double {
        let k = total.kcal
        guard k > 0 else { return 0 }
        return (byCategory[category]?.kcal ?? 0) / k
    }
}

public enum StatsEngine {
    /// Дни периода, содержащего `date` (для недели — с понедельника по воскресенье).
    public static func days(of period: StatsPeriod, containing date: Date, calendar: Calendar = .current) -> [Date] {
        var cal = calendar
        cal.firstWeekday = 2 // понедельник
        let start = cal.startOfDay(for: date)
        switch period {
        case .day:
            return [start]
        case .week:
            let weekday = cal.component(.weekday, from: start) // 1 = вс … 7 = сб
            let offset = (weekday + 5) % 7                     // пн → 0, вс → 6
            guard let monday = cal.date(byAdding: .day, value: -offset, to: start) else { return [start] }
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
        case .month:
            guard let range = cal.range(of: .day, in: .month, for: start),
                  let first = cal.date(from: cal.dateComponents([.year, .month], from: start)) else { return [start] }
            return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: first) }
        }
    }

    /// Первый и последний день периода.
    public static func bounds(of period: StatsPeriod, containing date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let d = days(of: period, containing: date, calendar: calendar)
        let last = d.last ?? d.first ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return (d.first ?? calendar.startOfDay(for: date), end)
    }

    /// Цели, действующие в указанный день: последний снимок с `effectiveFrom <= день`;
    /// если день раньше всех снимков — самый ранний снимок.
    public static func targets(for day: Date, in snapshots: [TargetSnapshot]) -> DailyTargets? {
        let sorted = snapshots.sorted { $0.effectiveFrom < $1.effectiveFrom }
        var current: DailyTargets? = sorted.first?.targets
        for s in sorted where s.effectiveFrom <= day {
            current = s.targets
        }
        return current
    }

    /// Основной расчёт.
    public static func compute(period: StatsPeriod, days: [Date], entries: [EntrySummary], targets: [TargetSnapshot],
                               calendar: Calendar = .current) -> PeriodStats {
        var byDay: [Date: [EntrySummary]] = [:]
        for e in entries {
            byDay[calendar.startOfDay(for: e.day), default: []].append(e)
        }
        var dayTotals: [DayTotals] = []
        var total = NutritionFacts.empty
        var byCategory: [MealCategory: NutritionFacts] = [:]
        var logged = 0
        var targetSum: DailyTargets? = nil
        for day in days {
            let dayEntries = byDay[calendar.startOfDay(for: day)] ?? []
            var cats: [MealCategory: NutritionFacts] = [:]
            for e in dayEntries {
                cats[e.category] = (cats[e.category] ?? .empty) + e.facts
            }
            let facts = NutritionFacts.sum(dayEntries.map { $0.facts })
            let t = StatsEngine.targets(for: day, in: targets)
            dayTotals.append(DayTotals(day: day, facts: facts, byCategory: cats, targets: t, entryCount: dayEntries.count))
            if !dayEntries.isEmpty {
                logged += 1
                total = total + facts
                for (c, f) in cats {
                    byCategory[c] = (byCategory[c] ?? .empty) + f
                }
                if let t = t {
                    targetSum = targetSum.map { $0 + t } ?? t
                }
            }
        }
        return PeriodStats(period: period, days: dayTotals, total: total, byCategory: byCategory, loggedDays: logged,
                           targetSum: targetSum)
    }
}
