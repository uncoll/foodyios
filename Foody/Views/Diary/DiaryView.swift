import SwiftUI
import SwiftData
import FoodyCore

/// Экран дневника: навигация по дням, сводка дня и записи по приёмам пищи.
struct DiaryView: View {
    @State private var day: Date = Calendar.current.startOfDay(for: Date())
    @State private var addCategory: MealCategory?
    @State private var showDatePicker = false

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    private var dayTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Сегодня" }
        if cal.isDateInYesterday(day) { return "Вчера" }
        if cal.isDateInTomorrow(day) { return "Завтра" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = cal.component(.year, from: day) == cal.component(.year, from: Date()) ? "EEEE, d MMMM" : "d MMMM yyyy"
        return f.string(from: day).prefix(1).uppercased() + f.string(from: day).dropFirst()
    }

    var body: some View {
        NavigationStack {
            DiaryDayView(day: day) { category in
                addCategory = category
            }
            .id(day)
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Предыдущий день")
                }
                ToolbarItem(placement: .principal) {
                    Button { showDatePicker = true } label: {
                        Text(dayTitle).font(.headline).foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if !isToday {
                            Button("Сегодня") { day = Calendar.current.startOfDay(for: Date()) }
                                .font(.subheadline)
                        }
                        Button { shift(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Следующий день")
                    }
                }
            }
            .sheet(item: $addCategory) { category in
                AddEntrySheet(day: day, initialCategory: category)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(day: $day)
            }
        }
    }

    private func shift(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: day) {
            day = Calendar.current.startOfDay(for: d)
        }
    }
}

struct DatePickerSheet: View {
    @Binding var day: Date
    @Environment(\.dismiss) private var dismiss
    @State private var picked = Date()

    var body: some View {
        NavigationStack {
            DatePicker("Дата", selection: $picked, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .padding()
                .navigationTitle("Выбрать день")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") {
                            day = Calendar.current.startOfDay(for: picked)
                            dismiss()
                        }
                    }
                }
                .onAppear { picked = day }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Содержимое одного дня. Пересоздаётся при смене дня (`.id(day)`), поэтому @Query строится в init.
struct DiaryDayView: View {
    let day: Date
    let onAdd: (MealCategory) -> Void

    @Environment(\.modelContext) private var context
    @Query private var entries: [DiaryEntry]
    @Query(sort: \TargetPlan.effectiveFrom) private var plans: [TargetPlan]
    @State private var editing: DiaryEntry?

    init(day: Date, onAdd: @escaping (MealCategory) -> Void) {
        self.day = day
        self.onAdd = onAdd
        let start = day
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        _entries = Query(filter: #Predicate<DiaryEntry> { $0.day >= start && $0.day < end },
                         sort: [SortDescriptor(\DiaryEntry.loggedAt)])
    }

    private var targets: DailyTargets? {
        StatsEngine.targets(for: day, in: plans.map { $0.snapshot })
    }

    private var totals: NutritionFacts {
        NutritionFacts.sum(entries.map { $0.totals })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                DaySummaryCard(totals: totals, targets: targets)
                ForEach(MealCategory.allCases) { category in
                    CategorySection(category: category,
                                    entries: entries.filter { $0.category == category },
                                    onAdd: { onAdd(category) },
                                    onEdit: { editing = $0 },
                                    onDelete: { delete($0) })
                }
                if !entries.isEmpty {
                    DayDetailsCard(totals: totals, targets: targets)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .sheet(item: $editing) { entry in
            EditEntrySheet(entry: entry)
        }
    }

    private func delete(_ entry: DiaryEntry) {
        withAnimation {
            context.delete(entry)
        }
    }
}

struct DaySummaryCard: View {
    let totals: NutritionFacts
    let targets: DailyTargets?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                MacroRing(value: totals.kcal, target: targets?.kcal)
                VStack(spacing: 10) {
                    MacroBar(macro: .protein, value: totals.proteinValue, target: targets?.protein, compact: true)
                    MacroBar(macro: .fat, value: totals.fatValue, target: targets?.fat, compact: true)
                    MacroBar(macro: .carbs, value: totals.carbsValue, target: targets?.carbs, compact: true)
                }
            }
            if let t = targets {
                let remaining = t.kcal - totals.kcal
                HStack {
                    if remaining >= 0 {
                        Text("Осталось \(NutrientFormatter.kcal(remaining)) ккал")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        BalanceBadge(balance: .over, delta: remaining, unit: "ккал")
                    }
                    Spacer()
                    Text("Цель \(NutrientFormatter.kcal(t.kcal)) ккал")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .card()
    }
}

/// Дополнительные показатели дня: клетчатка, сахара, насыщенные жиры, соль — с лимитами, если заданы.
struct DayDetailsCard: View {
    let totals: NutritionFacts
    let targets: DailyTargets?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Подробнее")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            detailRow("Клетчатка", totals.fiber, limit: targets?.fiberMin, isMinimum: true)
            detailRow("Сахара", totals.sugars, limit: targets?.sugarsMax, isMinimum: false)
            detailRow("Насыщенные жиры", totals.saturatedFat, limit: targets?.saturatedFatMax, isMinimum: false)
            detailRow("Соль", totals.saltResolved, limit: targets?.saltMax, isMinimum: false, precise: true)
        }
        .card()
    }

    @ViewBuilder
    private func detailRow(_ title: String, _ value: Double?, limit: Double?, isMinimum: Bool, precise: Bool = false) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            let text = value.map { precise ? NutrientFormatter.precise($0) : NutrientFormatter.grams($0) } ?? "—"
            if let limit, let v = value {
                let limitText = precise ? NutrientFormatter.precise(limit) : NutrientFormatter.grams(limit)
                let bad = isMinimum ? v < limit * 0.95 : v > limit * 1.05
                Text("\(text) / \(limitText) г")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(bad ? (isMinimum ? Theme.under : Theme.over) : .primary)
            } else {
                Text(value == nil ? "—" : "\(text) г")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(value == nil ? .tertiary : .primary)
            }
        }
    }
}

struct CategorySection: View {
    let category: MealCategory
    let entries: [DiaryEntry]
    let onAdd: () -> Void
    let onEdit: (DiaryEntry) -> Void
    let onDelete: (DiaryEntry) -> Void

    private var kcal: Double { entries.reduce(0) { $0 + $1.kcal } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: category.symbolName)
                    .foregroundStyle(Theme.color(for: category))
                Text(category.title)
                    .font(.headline)
                Spacer()
                if !entries.isEmpty {
                    Text("\(NutrientFormatter.kcal(kcal)) ккал")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить в \(category.title)")
            }
            .padding(.bottom, entries.isEmpty ? 0 : 8)

            ForEach(entries) { entry in
                Button { onEdit(entry) } label: {
                    DiaryEntryRow(entry: entry)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Изменить") { onEdit(entry) }
                    Button("Удалить", role: .destructive) { onDelete(entry) }
                }
                if entry.persistentModelID != entries.last?.persistentModelID {
                    Divider().padding(.leading, 4)
                }
            }
        }
        .card()
    }
}

struct DiaryEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(entry.amountLabel)
                    if !entry.detail.isEmpty {
                        Text("·")
                        Text(entry.detail).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(NutrientFormatter.kcal(entry.kcal))")
                    .font(.body.weight(.medium).monospacedDigit())
                MacroSummaryLine(facts: entry.totals, showKcal: false)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Правка записи: количество и приём пищи; удаление.
struct EditEntrySheet: View {
    @Bindable var entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var amount: Double = 0
    @State private var category: MealCategory = .breakfast

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(entry.name).font(.headline)
                    if !entry.detail.isEmpty { Text(entry.detail).foregroundStyle(.secondary) }
                }
                Section("Количество") {
                    RequiredDecimalField(title: "Количество", value: $amount, unit: entry.basis.unitSymbol)
                    AmountChips(options: [50, 100, 150, 200, 250, 300], unit: entry.basis.unitSymbol) { amount = $0 }
                }
                Section("Приём пищи") {
                    CategoryPicker(category: $category)
                }
                Section("Итого") {
                    let facts = entry.per100.forAmount(amount)
                    NutrientRow(title: "Калории", value: facts.kcal, unit: "ккал", emphasized: true)
                    NutrientRow(title: "Белки", value: facts.protein, unit: "г")
                    NutrientRow(title: "Жиры", value: facts.fat, unit: "г")
                    NutrientRow(title: "Углеводы", value: facts.carbohydrates, unit: "г")
                }
                Section {
                    Button("Удалить запись", role: .destructive) {
                        context.delete(entry)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        entry.amount = max(0, amount)
                        entry.category = category
                        entry.recalculateTotals()
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
            .onAppear {
                amount = entry.amount
                category = entry.category
            }
        }
    }
}
