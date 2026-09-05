import SwiftUI
import SwiftData
import FoodyCore

/// Добавление записи: поиск по продуктам, сохранённым приёмам и рецептам + быстрая запись КБЖУ.
struct AddEntrySheet: View {
    let day: Date
    @State var category: MealCategory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Product.name) private var products: [Product]
    @Query(sort: \SavedMeal.name) private var meals: [SavedMeal]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    @State private var mode: Mode = .products
    @State private var search = ""
    @State private var selectedProduct: Product?
    @State private var selectedRecipe: Recipe?
    @State private var selectedMeal: SavedMeal?
    @State private var showScan = false

    enum Mode: String, CaseIterable, Identifiable {
        case products = "Продукты", meals = "Приёмы", recipes = "Рецепты", quick = "Быстро"
        var id: String { rawValue }
    }

    init(day: Date, initialCategory: MealCategory) {
        self.day = day
        _category = State(initialValue: initialCategory)
    }

    private var filteredProducts: [Product] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let base = q.isEmpty
            ? products.sorted { ($0.usageCount, $0.lastUsedAt ?? .distantPast) > ($1.usageCount, $1.lastUsedAt ?? .distantPast) }
            : products.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.brand.localizedCaseInsensitiveContains(q) }
        return base
    }

    private var filteredMeals: [SavedMeal] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? meals : meals.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var filteredRecipes: [Recipe] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? recipes : recipes.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    CategoryPicker(category: $category)
                    Picker("Источник", selection: $mode) {
                        ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch mode {
                case .products: productList
                case .meals: mealList
                case .recipes: recipeList
                case .quick: QuickAddView(day: day, category: category) { dismiss() }
                }
            }
            .background(Theme.background)
            .navigationTitle("Добавить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
            .sheet(item: $selectedProduct) { product in
                ProductAmountSheet(product: product, category: category, day: day) { dismiss() }
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeAmountSheet(recipe: recipe, category: category, day: day) { dismiss() }
            }
            .sheet(item: $selectedMeal) { meal in
                MealConfirmSheet(meal: meal, category: category, day: day) { dismiss() }
            }
            .sheet(isPresented: $showScan) {
                LabelScanFlowView { product in
                    selectedProduct = product
                }
            }
        }
    }

    private var productList: some View {
        List {
            if search.isEmpty {
                Section {
                    Button {
                        showScan = true
                    } label: {
                        Label("Сфотографировать этикетку", systemImage: "camera.viewfinder")
                    }
                }
            }
            if filteredProducts.isEmpty {
                ContentUnavailableView(search.isEmpty ? "Нет продуктов" : "Ничего не найдено",
                                       systemImage: "carrot",
                                       description: Text(search.isEmpty ? "Добавьте продукты на вкладке «Продукты» или сфотографируйте этикетку." : "Попробуйте другое название."))
            } else {
                Section(search.isEmpty ? "Часто используемые" : "Продукты") {
                    ForEach(filteredProducts) { p in
                        Button { selectedProduct = p } label: {
                            ProductRow(product: p)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск")
        .scrollDismissesKeyboard(.immediately)
    }

    private var mealList: some View {
        List {
            if filteredMeals.isEmpty {
                ContentUnavailableView("Нет сохранённых приёмов", systemImage: "fork.knife",
                                       description: Text("Соберите частые завтраки, обеды и ужины на вкладке «Продукты» → «Приёмы»."))
            } else {
                ForEach(filteredMeals) { m in
                    Button { selectedMeal = m } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(m.name)
                            Text(m.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск")
    }

    private var recipeList: some View {
        List {
            if filteredRecipes.isEmpty {
                ContentUnavailableView("Нет рецептов", systemImage: "frying.pan",
                                       description: Text("Создайте рецепт на вкладке «Продукты» → «Рецепты»."))
            } else {
                ForEach(filteredRecipes) { r in
                    Button { selectedRecipe = r } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.name)
                            Text(r.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск")
    }
}

/// Строка продукта в списках.
struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(product.name).lineLimit(1)
                    if product.isFavorite {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.fat)
                    }
                    if product.isFromPhoto {
                        Image(systemName: "camera").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(product.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            MacroSummaryLine(facts: product.facts, showKcal: false)
        }
        .contentShape(Rectangle())
    }
}

/// Количество продукта → запись в дневник.
struct ProductAmountSheet: View {
    let product: Product
    @State var category: MealCategory
    let day: Date
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var amount: Double = 100

    init(product: Product, category: MealCategory, day: Date, onDone: @escaping () -> Void) {
        self.product = product
        _category = State(initialValue: category)
        self.day = day
        self.onDone = onDone
        _amount = State(initialValue: product.servingSize ?? 100)
    }

    private var chips: [Double] {
        var values: [Double] = []
        if let s = product.servingSize, s > 0 { values.append(s) }
        values += [50, 100, 150, 200, 250]
        var seen = Set<Double>()
        return values.filter { seen.insert($0).inserted }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(product.name).font(.headline)
                    if !product.brand.isEmpty { Text(product.brand).foregroundStyle(.secondary) }
                }
                Section("Количество") {
                    RequiredDecimalField(title: "Количество", value: $amount, unit: product.basis.unitSymbol)
                    AmountChips(options: chips, unit: product.basis.unitSymbol) { amount = $0 }
                    if let s = product.servingSize, s > 0 {
                        Text("Порция: \(product.servingName ?? "") \(NutrientFormatter.grams(s)) \(product.basis.unitSymbol)")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Приём пищи") {
                    CategoryPicker(category: $category)
                }
                Section("Итого") {
                    let facts = product.facts.forAmount(amount)
                    NutrientRow(title: "Калории", value: facts.kcal, unit: "ккал", emphasized: true)
                    NutrientRow(title: "Белки", value: facts.protein, unit: "г")
                    NutrientRow(title: "Жиры", value: facts.fat, unit: "г")
                    NutrientRow(title: "Углеводы", value: facts.carbohydrates, unit: "г")
                }
            }
            .navigationTitle("Количество")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Назад") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        DiaryService.log(product: product, amount: amount, category: category, day: day, context: context)
                        dismiss()
                        onDone()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}

/// Рецепт: количество в граммах или в порциях.
struct RecipeAmountSheet: View {
    let recipe: Recipe
    @State var category: MealCategory
    let day: Date
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var portions: Double = 1
    @State private var grams: Double = 0
    @State private var byPortions = true

    init(recipe: Recipe, category: MealCategory, day: Date, onDone: @escaping () -> Void) {
        self.recipe = recipe
        _category = State(initialValue: category)
        self.day = day
        self.onDone = onDone
        _grams = State(initialValue: recipe.effectivePortionWeight)
    }

    private var amountGrams: Double {
        byPortions ? portions * recipe.effectivePortionWeight : grams
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(recipe.name).font(.headline)
                    Text("Порция \(NutrientFormatter.grams(recipe.effectivePortionWeight)) г · \(NutrientFormatter.kcal(recipe.kcalPer100)) ккал на 100 г")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Количество") {
                    Picker("Единицы", selection: $byPortions) {
                        Text("Порции").tag(true)
                        Text("Граммы").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if byPortions {
                        RequiredDecimalField(title: "Порций", value: $portions)
                        AmountChips(options: [0.5, 1, 1.5, 2], unit: "порц.") { portions = $0 }
                    } else {
                        RequiredDecimalField(title: "Вес", value: $grams, unit: "г")
                        AmountChips(options: [100, 150, 200, 250, 300, 400], unit: "г") { grams = $0 }
                    }
                }
                Section("Приём пищи") {
                    CategoryPicker(category: $category)
                }
                Section("Итого") {
                    let facts = recipe.per100.forAmount(amountGrams)
                    NutrientRow(title: "Калории", value: facts.kcal, unit: "ккал", emphasized: true)
                    NutrientRow(title: "Белки", value: facts.protein, unit: "г")
                    NutrientRow(title: "Жиры", value: facts.fat, unit: "г")
                    NutrientRow(title: "Углеводы", value: facts.carbohydrates, unit: "г")
                }
            }
            .navigationTitle("Рецепт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Назад") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        DiaryService.log(recipe: recipe, amount: amountGrams, category: category, day: day, context: context)
                        dismiss()
                        onDone()
                    }
                    .disabled(amountGrams <= 0)
                }
            }
        }
    }
}

/// Подтверждение добавления сохранённого приёма пищи.
struct MealConfirmSheet: View {
    let meal: SavedMeal
    @State var category: MealCategory
    let day: Date
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    init(meal: SavedMeal, category: MealCategory, day: Date, onDone: @escaping () -> Void) {
        self.meal = meal
        _category = State(initialValue: category)
        self.day = day
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(meal.name).font(.headline)
                    MacroSummaryLine(facts: meal.total)
                }
                Section("Состав") {
                    ForEach(meal.items) { item in
                        HStack {
                            Text(item.name).lineLimit(1)
                            Spacer()
                            Text("\(NutrientFormatter.grams(item.amount)) \(item.basis.unitSymbol) · \(NutrientFormatter.kcal(item.nutrients.kcal)) ккал")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Приём пищи") {
                    CategoryPicker(category: $category)
                }
            }
            .navigationTitle("Приём пищи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Назад") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        DiaryService.log(meal: meal, category: category, day: day, context: context)
                        dismiss()
                        onDone()
                    }
                }
            }
        }
    }
}

/// Быстрая запись без продукта.
struct QuickAddView: View {
    let day: Date
    let category: MealCategory
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var fat: Double?
    @State private var carbs: Double?

    private var facts: NutritionFacts {
        NutritionFacts(energyKcal: kcal, fat: fat, carbohydrates: carbs, protein: protein)
    }

    var body: some View {
        Form {
            Section("Что съели") {
                TextField("Название (необязательно)", text: $name)
            }
            Section("Пищевая ценность") {
                DecimalField(title: "Калории", value: $kcal, unit: "ккал")
                DecimalField(title: "Белки", value: $protein, unit: "г")
                DecimalField(title: "Жиры", value: $fat, unit: "г")
                DecimalField(title: "Углеводы", value: $carbs, unit: "г")
                if kcal == nil, let est = facts.estimatedKcalFromMacros, est > 0 {
                    Button("Рассчитать калории по БЖУ: \(NutrientFormatter.kcal(est)) ккал") { kcal = est.rounded() }
                }
            }
            Section {
                Button {
                    DiaryService.logQuick(name: name, facts: facts, category: category, day: day, context: context)
                    onDone()
                } label: {
                    Text("Добавить в \(category.title.lowercased())")
                        .frame(maxWidth: .infinity)
                }
                .disabled(facts.isEmpty)
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }
}
