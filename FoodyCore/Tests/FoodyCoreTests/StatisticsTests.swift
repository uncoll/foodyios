import XCTest
@testable import FoodyCore

final class StatisticsTests: XCTestCase {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin") ?? TimeZone(secondsFromGMT: 2 * 3600)!
        c.locale = Locale(identifier: "ru_RU")
        return c
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testWeekStartsOnMonday() {
        // 3 сентября 2026 — четверг
        let days = StatsEngine.days(of: .week, containing: date(2026, 9, 3), calendar: cal)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(cal.component(.day, from: days[0]), 31)   // понедельник 31 августа
        XCTAssertEqual(cal.component(.month, from: days[0]), 8)
        XCTAssertEqual(cal.component(.day, from: days[6]), 6)    // воскресенье 6 сентября
        // воскресенье относится к той же неделе
        let sunday = StatsEngine.days(of: .week, containing: date(2026, 9, 6), calendar: cal)
        XCTAssertEqual(sunday[0], days[0])
    }

    func testMonthDays() {
        let days = StatsEngine.days(of: .month, containing: date(2026, 2, 10), calendar: cal)
        XCTAssertEqual(days.count, 28)
        XCTAssertEqual(cal.component(.day, from: days[0]), 1)
        let bounds = StatsEngine.bounds(of: .month, containing: date(2026, 2, 10), calendar: cal)
        XCTAssertEqual(cal.component(.month, from: bounds.end), 3)
    }

    func testTargetsHistory() {
        let snaps = [TargetSnapshot(effectiveFrom: cal.startOfDay(for: date(2026, 9, 1)), targets: DailyTargets(kcal: 2000, protein: 100, fat: 70, carbs: 250)),
                     TargetSnapshot(effectiveFrom: cal.startOfDay(for: date(2026, 9, 5)), targets: DailyTargets(kcal: 1800, protein: 120, fat: 60, carbs: 200))]
        XCTAssertEqual(StatsEngine.targets(for: cal.startOfDay(for: date(2026, 8, 20)), in: snaps)?.kcal, 2000, "раньше первого снимка — берём первый")
        XCTAssertEqual(StatsEngine.targets(for: cal.startOfDay(for: date(2026, 9, 3)), in: snaps)?.kcal, 2000)
        XCTAssertEqual(StatsEngine.targets(for: cal.startOfDay(for: date(2026, 9, 5)), in: snaps)?.kcal, 1800)
        XCTAssertEqual(StatsEngine.targets(for: cal.startOfDay(for: date(2026, 9, 9)), in: snaps)?.kcal, 1800)
        XCTAssertNil(StatsEngine.targets(for: Date(), in: []))
    }

    func testWeekStatsWithOverAndUnder() {
        let t = DailyTargets(kcal: 2000, protein: 100, fat: 70, carbs: 250)
        let snaps = [TargetSnapshot(effectiveFrom: cal.startOfDay(for: date(2026, 1, 1)), targets: t)]
        let mon = cal.startOfDay(for: date(2026, 8, 31))
        let tue = cal.startOfDay(for: date(2026, 9, 1))
        let wed = cal.startOfDay(for: date(2026, 9, 2))
        let entries = [
            EntrySummary(day: mon, category: .breakfast, facts: NutritionFacts(kcal: 600, protein: 30, fat: 20, carbs: 70)),
            EntrySummary(day: mon, category: .lunch, facts: NutritionFacts(kcal: 900, protein: 40, fat: 30, carbs: 100)),
            EntrySummary(day: mon, category: .dinner, facts: NutritionFacts(kcal: 800, protein: 40, fat: 30, carbs: 80)),   // 2300 — перебор
            EntrySummary(day: tue, category: .breakfast, facts: NutritionFacts(kcal: 500, protein: 20, fat: 15, carbs: 60)),
            EntrySummary(day: tue, category: .snack, facts: NutritionFacts(kcal: 200, protein: 5, fat: 10, carbs: 20)),        // 700 — недобор
            EntrySummary(day: wed, category: .lunch, facts: NutritionFacts(kcal: 2000, protein: 100, fat: 70, carbs: 250)),  // ровно цель
        ]
        let days = StatsEngine.days(of: .week, containing: wed, calendar: cal)
        let stats = StatsEngine.compute(period: .week, days: days, entries: entries, targets: snaps, calendar: cal)
        XCTAssertEqual(stats.days.count, 7)
        XCTAssertEqual(stats.loggedDays, 3)
        XCTAssertEqual(stats.total.kcal, 5000, accuracy: 0.001)
        XCTAssertEqual(stats.targetSum?.kcal, 6000)
        XCTAssertEqual(stats.delta(.kcal) ?? 0, -1000, accuracy: 0.001)
        XCTAssertEqual(stats.balance(.kcal), .under)
        XCTAssertEqual(stats.averagePerLoggedDay.kcal, 5000.0 / 3, accuracy: 0.001)
        XCTAssertEqual(stats.daysOverKcal, 1)
        XCTAssertEqual(stats.daysUnderKcal, 1)
        XCTAssertEqual(stats.byCategory[.breakfast]?.kcal ?? 0, 1100, accuracy: 0.001)
        XCTAssertEqual(stats.byCategory[.lunch]?.kcal ?? 0, 2900, accuracy: 0.001)
        XCTAssertEqual(stats.categoryShare(.dinner), 800.0 / 5000, accuracy: 0.0001)
        let monday = stats.days[0]
        XCTAssertEqual(monday.entryCount, 3)
        XCTAssertEqual(monday.delta(.kcal) ?? 0, 300, accuracy: 0.001)
        XCTAssertEqual(monday.progress(.protein) ?? 0, 1.1, accuracy: 0.001)
        XCTAssertFalse(stats.days[3].hasEntries)
        XCTAssertNotNil(stats.days[3].targets, "цели есть и у пустых дней")
    }

    func testBalanceTolerance() {
        XCTAssertEqual(Balance.evaluate(actual: 2050, target: 2000), .onTarget)
        XCTAssertEqual(Balance.evaluate(actual: 2200, target: 2000), .over)
        XCTAssertEqual(Balance.evaluate(actual: 1800, target: 2000), .under)
        XCTAssertEqual(Balance.evaluate(actual: 100, target: 0), .onTarget)
    }

    func testTargetCalculator() {
        let t = TargetCalculator.targets(sex: .male, weightKg: 80, heightCm: 180, age: 35, activity: .moderate, goal: .maintain)
        // BMR = 10*80 + 6.25*180 - 5*35 + 5 = 1755; ×1.55 = 2720.25
        XCTAssertEqual(t.kcal, 2720, accuracy: 1)
        XCTAssertEqual(t.protein, 144)
        XCTAssertEqual(t.fat, 72)
        XCTAssertEqual(t.carbs, 374, accuracy: 1)
        XCTAssertEqual(MealCategory.suggested(forHour: 8), .breakfast)
        XCTAssertEqual(MealCategory.suggested(forHour: 13), .lunch)
        XCTAssertEqual(MealCategory.suggested(forHour: 19), .dinner)
        XCTAssertEqual(MealCategory.suggested(forHour: 23), .snack)
    }
}
