import SwiftUI
import SwiftData
import FoodyCore

/// Карточка продукта: полная таблица значений, порция, действия.
struct ProductDetailView: View {
    @Bindable var product: Product
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showLog = false
    @State private var showPhoto = false
    @State private var confirmDelete = false

    private var facts: NutritionFacts { product.facts }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if !product.brand.isEmpty {
                        Text(product.brand).font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        BigNumber(value: NutrientFormatter.kcal(facts.kcal), unit: "ккал \(product.basis.per100Title)")
                        Spacer()
                    }
                    MacroSummaryLine(facts: facts, showKcal: false)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    showLog = true
                } label: {
                    Label("Добавить в дневник", systemImage: "plus.circle.fill")
                }
            }

            Section("Пищевая ценность \(product.basis.per100Title)") {
                NutrientRow(title: "Энергия", value: facts.energyKcal, unit: "ккал", emphasized: true)
                NutrientRow(title: "Энергия", value: facts.kJ, unit: "кДж")
                NutrientRow(title: "Жиры", value: facts.fat, unit: "г", emphasized: true)
                NutrientRow(title: "насыщенные", value: facts.saturatedFat, unit: "г", indent: true)
                if facts.monounsaturatedFat != nil { NutrientRow(title: "мононенасыщенные", value: facts.monounsaturatedFat, unit: "г", indent: true) }
                if facts.polyunsaturatedFat != nil { NutrientRow(title: "полиненасыщенные", value: facts.polyunsaturatedFat, unit: "г", indent: true) }
                if facts.transFat != nil { NutrientRow(title: "трансжиры", value: facts.transFat, unit: "г", indent: true) }
                if facts.cholesterolMg != nil { NutrientRow(title: "Холестерин", value: facts.cholesterolMg, unit: "мг") }
                NutrientRow(title: "Углеводы", value: facts.carbohydrates, unit: "г", emphasized: true)
                NutrientRow(title: "сахара", value: facts.sugars, unit: "г", indent: true)
                if facts.polyols != nil { NutrientRow(title: "полиолы", value: facts.polyols, unit: "г", indent: true) }
                if facts.starch != nil { NutrientRow(title: "крахмал", value: facts.starch, unit: "г", indent: true) }
                NutrientRow(title: "Клетчатка", value: facts.fiber, unit: "г")
                NutrientRow(title: "Белки", value: facts.protein, unit: "г", emphasized: true)
                NutrientRow(title: "Соль", value: facts.saltResolved, unit: "г", emphasized: true)
                if facts.sodiumMg != nil { NutrientRow(title: "Натрий", value: facts.sodiumMg, unit: "мг") }
                if facts.alcohol != nil { NutrientRow(title: "Алкоголь", value: facts.alcohol, unit: "г") }
            }

            if !facts.micronutrients.isEmpty {
                Section("Витамины и минералы") {
                    ForEach(facts.micronutrients, id: \.key) { m in
                        HStack {
                            Text(m.title)
                            Spacer()
                            Text("\(NutrientFormatter.auto(m.amount)) \(m.unit)").monospacedDigit()
                            if let f = m.nrvFraction {
                                Text(NutrientFormatter.percent(f)).font(.caption).foregroundStyle(.secondary).frame(width: 48, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            if let s = product.servingSize, s > 0 {
                Section("Порция \(product.servingName ?? "") \(NutrientFormatter.grams(s)) \(product.basis.unitSymbol)") {
                    let p = facts.forAmount(s)
                    NutrientRow(title: "Энергия", value: p.kcal, unit: "ккал", emphasized: true)
                    NutrientRow(title: "Белки", value: p.protein, unit: "г")
                    NutrientRow(title: "Жиры", value: p.fat, unit: "г")
                    NutrientRow(title: "Углеводы", value: p.carbohydrates, unit: "г")
                }
            }

            if !product.notes.isEmpty {
                Section("Заметки") { Text(product.notes) }
            }

            if let data = product.labelImage, let image = UIImage(data: data) {
                Section("Фото этикетки") {
                    Button { showPhoto = true } label: {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                HStack {
                    Text("Добавлен").foregroundStyle(.secondary)
                    Spacer()
                    Text(product.createdAt, style: .date)
                }
                HStack {
                    Text("Использован").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(product.usageCount) раз")
                }
                Button("Удалить продукт", role: .destructive) { confirmDelete = true }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        product.isFavorite.toggle()
                    } label: {
                        Image(systemName: product.isFavorite ? "star.fill" : "star")
                    }
                    .tint(Theme.fat)
                    Button("Изменить") { showEdit = true }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            ProductFormView(mode: .edit(product))
        }
        .sheet(isPresented: $showLog) {
            ProductAmountSheet(product: product, category: MealCategory.suggested(for: Date()),
                               day: Calendar.current.startOfDay(for: Date())) { }
        }
        .sheet(isPresented: $showPhoto) {
            if let data = product.labelImage, let image = UIImage(data: data) {
                PhotoViewer(image: image)
            }
        }
        .confirmationDialog("Удалить продукт?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                context.delete(product)
                dismiss()
            }
        } message: {
            Text("Записи дневника сохранят свои значения.")
        }
    }
}

/// Выбор продукта с указанием количества — для рецептов и сохранённых приёмов.
struct ProductPickerView: View {
    let onPick: (Product, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Product.name) private var products: [Product]
    @State private var search = ""
    @State private var selected: Product?

    private var filtered: [Product] {
        let q = search.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            return products.sorted { ($0.usageCount, $0.name) > ($1.usageCount, $1.name) }
        }
        return products.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.brand.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    ContentUnavailableView("Нет продуктов", systemImage: "carrot",
                                           description: Text("Сначала добавьте продукты в базу."))
                } else {
                    ForEach(filtered) { p in
                        Button { selected = p } label: { ProductRow(product: p) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск продукта")
            .navigationTitle("Выбрать продукт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
            .sheet(item: $selected) { product in
                AmountPromptSheet(product: product) { amount in
                    onPick(product, amount)
                    dismiss()
                }
            }
        }
    }
}

struct AmountPromptSheet: View {
    let product: Product
    let onConfirm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 100

    init(product: Product, onConfirm: @escaping (Double) -> Void) {
        self.product = product
        self.onConfirm = onConfirm
        _amount = State(initialValue: product.servingSize ?? 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(product.name).font(.headline)
                }
                Section("Количество") {
                    RequiredDecimalField(title: "Количество", value: $amount, unit: product.basis.unitSymbol)
                    AmountChips(options: [30, 50, 100, 150, 200, 250], unit: product.basis.unitSymbol) { amount = $0 }
                }
                Section("В этом количестве") {
                    MacroSummaryLine(facts: product.facts.forAmount(amount))
                }
            }
            .navigationTitle("Количество")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Назад") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        onConfirm(amount)
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
