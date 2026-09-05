import SwiftUI
import SwiftData
import FoodyCore

/// Дневные цели по КБЖУ: правка, калькулятор, история.
struct TargetsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \TargetPlan.effectiveFrom, order: .reverse) private var plans: [TargetPlan]

    @State private var targets = DailyTargets.standard
    @State private var showCalculator = false
    @State private var showHistory = false
    @State private var loaded = false

    private var kcalFromMacros: Double { targets.kcalFromMacros }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RequiredDecimalField(title: "Калории", value: $targets.kcal, unit: "ккал")
                    RequiredDecimalField(title: "Белки", value: $targets.protein, unit: "г")
                    RequiredDecimalField(title: "Жиры", value: $targets.fat, unit: "г")
                    RequiredDecimalField(title: "Углеводы", value: $targets.carbs, unit: "г")
                } header: {
                    Text("Дневная цель")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("По БЖУ получается \(NutrientFormatter.kcal(kcalFromMacros)) ккал (4/9/4).")
                        if abs(kcalFromMacros - targets.kcal) > targets.kcal * 0.08 {
                            Button("Подставить \(NutrientFormatter.kcal(kcalFromMacros)) ккал") { targets.kcal = kcalFromMacros.rounded() }
                                .font(.footnote)
                        }
                    }
                }

                Section {
                    DecimalField(title: "Клетчатка, минимум", value: $targets.fiberMin, unit: "г")
                    DecimalField(title: "Сахара, максимум", value: $targets.sugarsMax, unit: "г")
                    DecimalField(title: "Насыщенные жиры, максимум", value: $targets.saturatedFatMax, unit: "г")
                    DecimalField(title: "Соль, максимум", value: $targets.saltMax, unit: "г")
                } header: {
                    Text("Дополнительные ориентиры")
                } footer: {
                    Text("Необязательно. Показываются в дневнике и статистике.")
                }

                Section {
                    Button { showCalculator = true } label: {
                        Label("Рассчитать по параметрам тела", systemImage: "function")
                    }
                    if plans.count > 1 {
                        Button { showHistory.toggle() } label: {
                            Label(showHistory ? "Скрыть историю" : "История изменений (\(plans.count))", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }

                if showHistory {
                    Section("История") {
                        ForEach(plans) { plan in
                            HStack {
                                Text(plan.effectiveFrom, style: .date)
                                Spacer()
                                Text("\(NutrientFormatter.kcal(plan.kcal)) ккал · Б \(NutrientFormatter.grams(plan.protein)) · Ж \(NutrientFormatter.grams(plan.fat)) · У \(NutrientFormatter.grams(plan.carbs))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Цели")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(targets.kcal <= 0)
                }
            }
            .sheet(isPresented: $showCalculator) {
                TargetCalculatorView { calculated in
                    targets = calculated
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let current = plans.first { targets = current.targets }
            }
        }
    }

    /// Новый план с сегодняшнего дня; если план уже начинается сегодня — правим его, чтобы не плодить записи.
    private func save() {
        let today = Calendar.current.startOfDay(for: Date())
        if let current = plans.first, current.effectiveFrom >= today {
            current.targets = targets
        } else {
            context.insert(TargetPlan(effectiveFrom: today, targets: targets))
        }
        dismiss()
    }
}

/// Калькулятор Миффлина — Сан Жеора.
struct TargetCalculatorView: View {
    let onApply: (DailyTargets) -> Void
    @Environment(\.dismiss) private var dismiss

    @AppStorage("calc.sex") private var sexRaw = TargetCalculator.Sex.male.rawValue
    @AppStorage("calc.weight") private var weight = 75.0
    @AppStorage("calc.height") private var height = 178.0
    @AppStorage("calc.age") private var age = 35
    @AppStorage("calc.activity") private var activityRaw = TargetCalculator.Activity.light.rawValue
    @AppStorage("calc.goal") private var goalRaw = TargetCalculator.Goal.maintain.rawValue

    private var sex: TargetCalculator.Sex { TargetCalculator.Sex(rawValue: sexRaw) ?? .male }
    private var activity: TargetCalculator.Activity { TargetCalculator.Activity(rawValue: activityRaw) ?? .light }
    private var goal: TargetCalculator.Goal { TargetCalculator.Goal(rawValue: goalRaw) ?? .maintain }

    private var result: DailyTargets {
        TargetCalculator.targets(sex: sex, weightKg: weight, heightCm: height, age: age, activity: activity, goal: goal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Параметры") {
                    Picker("Пол", selection: $sexRaw) {
                        ForEach(TargetCalculator.Sex.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    RequiredDecimalField(title: "Вес", value: $weight, unit: "кг")
                    RequiredDecimalField(title: "Рост", value: $height, unit: "см")
                    Stepper("Возраст: \(age)", value: $age, in: 14...100)
                }
                Section("Активность") {
                    Picker("Активность", selection: $activityRaw) {
                        ForEach(TargetCalculator.Activity.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Цель") {
                    Picker("Цель", selection: $goalRaw) {
                        ForEach(TargetCalculator.Goal.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Результат") {
                    NutrientRow(title: "Калории", value: result.kcal, unit: "ккал", emphasized: true)
                    NutrientRow(title: "Белки", value: result.protein, unit: "г")
                    NutrientRow(title: "Жиры", value: result.fat, unit: "г")
                    NutrientRow(title: "Углеводы", value: result.carbs, unit: "г")
                    Text("Формула Миффлина — Сан Жеора; белок 1,8–2 г/кг, жиры 0,9 г/кг, остальное — углеводы. Это ориентир, скорректируйте по самочувствию и динамике веса.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Калькулятор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Применить") {
                        onApply(result)
                        dismiss()
                    }
                }
            }
        }
    }
}
