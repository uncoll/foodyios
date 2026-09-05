import SwiftUI
import SwiftData
import Charts
import FoodyCore

/// Статистика: день / неделя / месяц, перебор-недобор по КБЖУ, разбивка по приёмам пищи.
struct StatsView: View {
    @Environment(\.modelContext) private var context
    @State private var period: StatsPeriod = .week
    @State private var anchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var stats: PeriodStats?
    @State private var showTargets = false

    private var days: [Date] { StatsEngine.days(of: period, containing: anchor) }

    private var periodTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        let cal = Calendar.current
        switch period {
        case .day:
            if cal.isDateInToday(anchor) { return "Сегодня" }
            f.dateFormat = "d MMMM"
            return f.string(from: anchor)
        case .week:
            guard let first = days.first, let last = days.last else { return "" }
            let f2 = DateFormatter()
            f2.locale = f.locale
            f.dateFormat = cal.isDate(first, equalTo: last, toGranularity: .month) ? "d" : "d MMM"
            f2.dateFormat = "d MMM"
            return "\(f.string(from: first)) – \(f2.string(from: last))"
        case .month:
            f.dateFormat = "LLLL yyyy"
            return f.string(from: anchor).prefix(1).uppercased() + f.string(from: anchor).dropFirst()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Период", selection: $period) {
                        ForEach(StatsPeriod.allCases) { p in Text(p.title).tag(p) }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(periodTitle).font(.headline)
                        Spacer()
                        Button { shift(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(isCurrentPeriod)
                    }
                    .padding(.horizontal, 4)

                    if let s = stats {
                        if s.loggedDays == 0 {
                            EmptyStateView(title: "Нет записей", message: "За этот период в дневнике ничего нет.", symbol: "chart.bar")
                                .frame(minHeight: 240)
                        } else {
                            SummaryCard(stats: s)
                            if period != .day {
                                KcalChartCard(stats: s, period: period)
                            }
                            MacroDeltaCard(stats: s)
                            CategoryBreakdownCard(stats: s)
                            ExtraNutrientsCard(stats: s)
                        }
                    } else {
                        ProgressView().frame(minHeight: 200)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Theme.background)
            .navigationTitle("Статистика")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTargets = true } label: { Label("Цели", systemImage: "target") }
                }
            }
            .sheet(isPresented: $showTargets) { TargetsView() }
            .onAppear(perform: reload)
            .onChange(of: period) { _, _ in reload() }
            .onChange(of: anchor) { _, _ in reload() }
            .onChange(of: showTargets) { _, shown in if !shown { reload() } }
        }
    }

    private var isCurrentPeriod: Bool {
        days.contains { Calendar.current.isDateInToday($0) } || (days.first ?? anchor) > Date()
    }

    private func shift(_ delta: Int) {
        let component: Calendar.Component = period == .day ? .day : (period == .week ? .weekOfYear : .month)
        if let d = Calendar.current.date(byAdding: component, value: delta, to: anchor) {
            anchor = Calendar.current.startOfDay(for: d)
        }
    }

    private func reload() {
        let bounds = StatsEngine.bounds(of: period, containing: anchor)
        let entries = DiaryService.entries(from: bounds.start, to: bounds.end, context: context).map { $0.summary }
        let targets = DiaryService.targetSnapshots(context: context)
        stats = StatsEngine.compute(period: period, days: days, entries: entries, targets: targets)
    }
}

// MARK: - Карточки

struct SummaryCard: View {
    let stats: PeriodStats

    private var isSingleDay: Bool { stats.period == .day }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isSingleDay ? "Калории за день" : "В среднем за день")
                        .font(.subheadline).foregroundStyle(.secondary)
                    BigNumber(value: NutrientFormatter.kcal(isSingleDay ? stats.total.kcal : stats.averagePerLoggedDay.kcal), unit: "ккал")
                    if let t = stats.averageTarget {
                        Text("цель \(NutrientFormatter.kcal(t.kcal)) ккал").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if let b = stats.balance(.kcal), let d = stats.delta(.kcal) {
                    BalanceBadge(balance: b, delta: isSingleDay ? d : d / Double(max(stats.loggedDays, 1)), unit: "ккал")
                }
            }
            if !isSingleDay {
                Divider()
                HStack {
                    statCell("Дней с записями", "\(stats.loggedDays) из \(stats.days.count)")
                    Divider().frame(height: 28)
                    statCell("Перебор", "\(stats.daysOverKcal) дн.", color: stats.daysOverKcal > 0 ? Theme.over : .primary)
                    Divider().frame(height: 28)
                    statCell("Недобор", "\(stats.daysUnderKcal) дн.", color: stats.daysUnderKcal > 0 ? Theme.under : .primary)
                }
                if let d = stats.delta(.kcal), stats.targetSum != nil {
                    Text(d >= 0
                         ? "За период суммарно на \(NutrientFormatter.kcal(d)) ккал больше цели."
                         : "За период суммарно на \(NutrientFormatter.kcal(-d)) ккал меньше цели.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    private func statCell(_ title: String, _ value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct KcalChartCard: View {
    let stats: PeriodStats
    let period: StatsPeriod

    private var target: Double? { stats.averageTarget?.kcal }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Калории по дням").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Chart {
                ForEach(stats.days) { day in
                    BarMark(x: .value("День", day.day, unit: .day), y: .value("ккал", day.facts.kcal))
                        .foregroundStyle(barColor(day))
                        .cornerRadius(3)
                }
                if let t = target {
                    RuleMark(y: .value("Цель", t))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("цель \(NutrientFormatter.kcal(t))").font(.caption2).foregroundStyle(.secondary)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: period == .week ? .dateTime.weekday(.narrow) : .dateTime.day(), centered: period == .week)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
            HStack(spacing: 14) {
                legend(Theme.accent, "в норме")
                legend(Theme.over, "перебор")
                legend(Theme.under, "недобор")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .card()
    }

    private func barColor(_ day: DayTotals) -> Color {
        guard day.hasEntries else { return Theme.accent.opacity(0.2) }
        guard let t = day.targets else { return Theme.accent }
        switch Balance.evaluate(actual: day.facts.kcal, target: t.kcal) {
        case .over: return Theme.over
        case .under: return Theme.under
        case .onTarget: return Theme.accent
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }
}

struct MacroDeltaCard: View {
    let stats: PeriodStats

    private var divisor: Double { stats.period == .day ? 1 : Double(max(stats.loggedDays, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stats.period == .day ? "Макронутриенты" : "Макронутриенты, в среднем за день")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            ForEach([Macro.protein, .fat, .carbs]) { m in
                let value = m.value(in: stats.total) / divisor
                let target = stats.targetSum.map { $0.value(for: m) / divisor }
                VStack(alignment: .leading, spacing: 6) {
                    MacroBar(macro: m, value: value, target: target)
                    if let t = target {
                        let b = Balance.evaluate(actual: value, target: t)
                        HStack {
                            BalanceBadge(balance: b, delta: value - t, unit: "г")
                            Spacer()
                            Text(NutrientFormatter.percent(t > 0 ? value / t : 0))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .card()
    }
}

struct CategoryBreakdownCard: View {
    let stats: PeriodStats

    private var divisor: Double { stats.period == .day ? 1 : Double(max(stats.loggedDays, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stats.period == .day ? "По приёмам пищи" : "По приёмам пищи, в среднем за день")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(MealCategory.allCases) { c in
                        let share = stats.categoryShare(c)
                        if share > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.color(for: c))
                                .frame(width: max(4, geo.size.width * share))
                        }
                    }
                }
            }
            .frame(height: 10)

            ForEach(MealCategory.allCases) { c in
                let facts = (stats.byCategory[c] ?? .empty).scaled(by: 1 / divisor)
                HStack(spacing: 10) {
                    Image(systemName: c.symbolName).foregroundStyle(Theme.color(for: c)).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(c.title).font(.subheadline)
                            Spacer()
                            Text("\(NutrientFormatter.kcal(facts.kcal)) ккал · \(NutrientFormatter.percent(stats.categoryShare(c)))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(facts.kcal > 0 ? .primary : .tertiary)
                        }
                        if facts.kcal > 0 {
                            MacroSummaryLine(facts: facts, showKcal: false)
                        }
                    }
                }
            }
        }
        .card()
    }
}

struct ExtraNutrientsCard: View {
    let stats: PeriodStats

    private var divisor: Double { stats.period == .day ? 1 : Double(max(stats.loggedDays, 1)) }
    private var facts: NutritionFacts { stats.total.scaled(by: 1 / divisor) }
    private var targets: DailyTargets? { stats.averageTarget }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stats.period == .day ? "Прочее" : "Прочее, в среднем за день")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            row("Клетчатка", facts.fiber, limit: targets?.fiberMin, isMinimum: true)
            row("Сахара", facts.sugars, limit: targets?.sugarsMax, isMinimum: false)
            row("Насыщенные жиры", facts.saturatedFat, limit: targets?.saturatedFatMax, isMinimum: false)
            row("Соль", facts.saltResolved, limit: targets?.saltMax, isMinimum: false)
        }
        .card()
    }

    private func row(_ title: String, _ value: Double?, limit: Double?, isMinimum: Bool) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            if let v = value {
                if let l = limit {
                    let bad = isMinimum ? v < l * 0.95 : v > l * 1.05
                    Text("\(NutrientFormatter.grams(v)) / \(NutrientFormatter.grams(l)) г")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(bad ? (isMinimum ? Theme.under : Theme.over) : .primary)
                } else {
                    Text("\(NutrientFormatter.grams(v)) г").font(.subheadline.monospacedDigit())
                }
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
    }
}
