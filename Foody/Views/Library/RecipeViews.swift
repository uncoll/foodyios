import SwiftUI
import SwiftData
import FoodyCore

/// Создание и правка рецепта: ингредиенты, вес готового блюда, стандартная порция.
struct RecipeFormView: View {
    let recipe: Recipe?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var notes = ""
    @State private var items: [RecipeItem] = []
    @State private var finalWeight: Double?
    @State private var portionWeight: Double?
    @State private var showPicker = false
    @State private var editingItem: RecipeItem?

    private var summary: RecipeSummary {
        RecipeMath.summary(items: items.map { $0.input }, finalWeight: finalWeight, portionWeight: portionWeight)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !items.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Рецепт") {
                    TextField("Название", text: $name)
                }

                Section {
                    ForEach(items) { item in
                        Button { editingItem = item } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).lineLimit(1)
                                    Text("\(NutrientFormatter.grams(item.amount)) \(item.basis.unitSymbol)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(NutrientFormatter.kcal(item.nutrients.kcal)) ккал")
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in items.remove(atOffsets: offsets) }
                    Button { showPicker = true } label: {
                        Label("Добавить ингредиент", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Ингредиенты")
                } footer: {
                    if !items.isEmpty {
                        Text("Сумма ингредиентов: \(NutrientFormatter.grams(summary.rawWeight)) г, \(NutrientFormatter.kcal(summary.total.kcal)) ккал.")
                    }
                }

                Section {
                    DecimalField(title: "Вес готового блюда", value: $finalWeight, unit: "г",
                                 placeholder: NutrientFormatter.grams(summary.rawWeight))
                    DecimalField(title: "Стандартная порция", value: $portionWeight, unit: "г",
                                 placeholder: NutrientFormatter.grams(summary.finalWeight))
                } header: {
                    Text("Вес и порция")
                } footer: {
                    Text("Взвесьте блюдо после приготовления — вода выкипает или впитывается, и калорийность на 100 г меняется. Если оставить пустым, берётся сумма ингредиентов.")
                }

                if !items.isEmpty {
                    Section("Расчёт") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("На 100 г").font(.caption).foregroundStyle(.secondary)
                                MacroSummaryLine(facts: summary.per100)
                            }
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("На порцию \(NutrientFormatter.grams(summary.portionWeight)) г (\(NutrientFormatter.grams(summary.portionsCount)) порц. в блюде)")
                                    .font(.caption).foregroundStyle(.secondary)
                                MacroSummaryLine(facts: summary.perPortion)
                            }
                        }
                    }
                }

                Section("Заметки") {
                    TextField("Способ приготовления, примечания…", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(recipe == nil ? "Новый рецепт" : "Рецепт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.disabled(!canSave) }
            }
            .sheet(isPresented: $showPicker) {
                ProductPickerView { product, amount in
                    items.append(RecipeItem(product: product, amount: amount))
                }
            }
            .sheet(item: $editingItem) { item in
                ItemAmountSheet(item: item) { newAmount in
                    if let idx = items.firstIndex(where: { $0.id == item.id }) {
                        items[idx].amount = newAmount
                    }
                }
            }
            .onAppear {
                if let r = recipe {
                    name = r.name
                    notes = r.notes
                    items = r.items
                    finalWeight = r.finalWeight
                    portionWeight = r.portionWeight
                }
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        if let r = recipe {
            r.name = cleanName
            r.notes = notes
            r.finalWeight = finalWeight
            r.portionWeight = portionWeight
            r.items = items
        } else {
            context.insert(Recipe(name: cleanName, items: items, finalWeight: finalWeight, portionWeight: portionWeight, notes: notes))
        }
        dismiss()
    }
}

/// Изменение количества ингредиента.
struct ItemAmountSheet: View {
    let item: RecipeItem
    let onConfirm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(item.name).font(.headline) }
                Section("Количество") {
                    RequiredDecimalField(title: "Количество", value: $amount, unit: item.basis.unitSymbol)
                    AmountChips(options: [30, 50, 100, 150, 200, 300], unit: item.basis.unitSymbol) { amount = $0 }
                }
            }
            .navigationTitle("Количество")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        onConfirm(amount)
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
            .onAppear { amount = item.amount }
        }
        .presentationDetents([.medium])
    }
}

/// Карточка рецепта.
struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showLog = false
    @State private var confirmDelete = false

    private var summary: RecipeSummary { recipe.summary }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    BigNumber(value: NutrientFormatter.kcal(summary.perPortion.kcal),
                              unit: "ккал на порцию \(NutrientFormatter.grams(summary.portionWeight)) г")
                    MacroSummaryLine(facts: summary.perPortion, showKcal: false)
                    Divider()
                    HStack {
                        Text("На 100 г").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        MacroSummaryLine(facts: summary.per100)
                    }
                    HStack {
                        Text("Всё блюдо \(NutrientFormatter.grams(summary.finalWeight)) г").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        MacroSummaryLine(facts: summary.total)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button { showLog = true } label: { Label("Добавить в дневник", systemImage: "plus.circle.fill") }
            }

            Section("Ингредиенты") {
                ForEach(recipe.items) { item in
                    HStack {
                        Text(item.name).lineLimit(1)
                        Spacer()
                        Text("\(NutrientFormatter.grams(item.amount)) \(item.basis.unitSymbol) · \(NutrientFormatter.kcal(item.nutrients.kcal)) ккал")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Пищевая ценность на 100 г готового блюда") {
                let f = summary.per100
                NutrientRow(title: "Энергия", value: f.kcal, unit: "ккал", emphasized: true)
                NutrientRow(title: "Жиры", value: f.fat, unit: "г", emphasized: true)
                NutrientRow(title: "насыщенные", value: f.saturatedFat, unit: "г", indent: true)
                NutrientRow(title: "Углеводы", value: f.carbohydrates, unit: "г", emphasized: true)
                NutrientRow(title: "сахара", value: f.sugars, unit: "г", indent: true)
                NutrientRow(title: "Клетчатка", value: f.fiber, unit: "г")
                NutrientRow(title: "Белки", value: f.protein, unit: "г", emphasized: true)
                NutrientRow(title: "Соль", value: f.saltResolved, unit: "г", emphasized: true)
            }

            if !recipe.notes.isEmpty {
                Section("Заметки") { Text(recipe.notes) }
            }

            Section {
                Button("Удалить рецепт", role: .destructive) { confirmDelete = true }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Изменить") { showEdit = true } }
        }
        .sheet(isPresented: $showEdit) { RecipeFormView(recipe: recipe) }
        .sheet(isPresented: $showLog) {
            RecipeAmountSheet(recipe: recipe, category: MealCategory.suggested(for: Date()),
                              day: Calendar.current.startOfDay(for: Date())) { }
        }
        .confirmationDialog("Удалить рецепт?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                context.delete(recipe)
                dismiss()
            }
        }
    }
}

/// Сохранённый приём пищи: название, приём по умолчанию, состав.
struct SavedMealFormView: View {
    let meal: SavedMeal?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var category: MealCategory = .breakfast
    @State private var items: [RecipeItem] = []
    @State private var showPicker = false
    @State private var editingItem: RecipeItem?
    @State private var showLog = false
    @State private var confirmDelete = false

    private var total: NutritionFacts { NutritionFacts.sum(items.map { $0.nutrients }) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !items.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Приём пищи") {
                    TextField("Название (например, «Овсянка с бананом»)", text: $name)
                    CategoryPicker(category: $category)
                }
                Section {
                    ForEach(items) { item in
                        Button { editingItem = item } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).lineLimit(1)
                                    Text("\(NutrientFormatter.grams(item.amount)) \(item.basis.unitSymbol)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(NutrientFormatter.kcal(item.nutrients.kcal)) ккал")
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in items.remove(atOffsets: offsets) }
                    Button { showPicker = true } label: { Label("Добавить продукт", systemImage: "plus.circle") }
                } header: {
                    Text("Состав")
                } footer: {
                    if !items.isEmpty {
                        MacroSummaryLine(facts: total)
                    }
                }
                if let m = meal {
                    Section {
                        Button { showLog = true } label: { Label("Добавить в дневник сегодня", systemImage: "plus.circle.fill") }
                        Button("Удалить приём пищи", role: .destructive) { confirmDelete = true }
                    }
                    .confirmationDialog("Удалить сохранённый приём?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Удалить", role: .destructive) {
                            context.delete(m)
                            dismiss()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(meal == nil ? "Новый приём пищи" : "Приём пищи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.disabled(!canSave) }
            }
            .sheet(isPresented: $showPicker) {
                ProductPickerView { product, amount in
                    items.append(RecipeItem(product: product, amount: amount))
                }
            }
            .sheet(item: $editingItem) { item in
                ItemAmountSheet(item: item) { newAmount in
                    if let idx = items.firstIndex(where: { $0.id == item.id }) {
                        items[idx].amount = newAmount
                    }
                }
            }
            .sheet(isPresented: $showLog) {
                if let m = meal {
                    MealConfirmSheet(meal: m, category: m.category, day: Calendar.current.startOfDay(for: Date())) { dismiss() }
                }
            }
            .onAppear {
                if let m = meal {
                    name = m.name
                    category = m.category
                    items = m.items
                }
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        if let m = meal {
            m.name = cleanName
            m.category = category
            m.items = items
        } else {
            context.insert(SavedMeal(name: cleanName, category: category, items: items))
        }
        dismiss()
    }
}
