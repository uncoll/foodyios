import SwiftUI
import SwiftData
import FoodyCore

/// Форма продукта: ручной ввод, правка и проверка черновика после распознавания этикетки.
struct ProductFormView: View {
    enum Mode {
        case create(ProductDraft)
        case edit(Product)
    }

    let mode: Mode
    var onSaved: ((Product) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var brand = ""
    @State private var basis: MeasureBasis = .grams
    @State private var servingSize: Double?
    @State private var servingName = ""
    @State private var facts = NutritionFacts()
    @State private var notes = ""
    @State private var reviewHint = ""
    @State private var modelInfo = ""
    @State private var labelImage: Data?
    @State private var showMicroPicker = false
    @State private var showPhoto = false
    @State private var loaded = false

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !facts.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if !reviewHint.isEmpty {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Проверьте распознанные данные").font(.subheadline.weight(.semibold))
                                Text(reviewHint).font(.footnote)
                                if !modelInfo.isEmpty { Text(modelInfo).font(.caption2).foregroundStyle(.tertiary) }
                            }
                        } icon: {
                            Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                        }
                    }
                }

                Section("Продукт") {
                    TextField("Название", text: $name)
                    TextField("Бренд (необязательно)", text: $brand)
                    Picker("Значения указаны", selection: $basis) {
                        Text("на 100 г").tag(MeasureBasis.grams)
                        Text("на 100 мл").tag(MeasureBasis.milliliters)
                    }
                    DecimalField(title: "Порция", value: $servingSize, unit: basis.unitSymbol)
                    TextField("Название порции (1 шт, стакан…)", text: $servingName)
                }

                Section {
                    DecimalField(title: "Энергия", value: $facts.energyKcal, unit: "ккал")
                    DecimalField(title: "Энергия", value: $facts.energyKJ, unit: "кДж")
                    if facts.energyKcal == nil, let est = facts.estimatedKcalFromMacros, est > 0 {
                        Button("Рассчитать по БЖУ: \(NutrientFormatter.kcal(est)) ккал") { facts.energyKcal = est.rounded() }
                    }
                    if facts.energyKcal != nil, facts.energyKJ == nil {
                        Button("Заполнить кДж из ккал") { facts.energyKJ = ((facts.energyKcal ?? 0) * 4.184).rounded() }
                            .font(.footnote)
                    }
                } header: {
                    Text("Энергия \(basis.per100Title)")
                }

                Section("Жиры") {
                    DecimalField(title: "Жиры", value: $facts.fat, unit: "г")
                    DecimalField(title: "  насыщенные", value: $facts.saturatedFat, unit: "г")
                    DecimalField(title: "  мононенасыщенные", value: $facts.monounsaturatedFat, unit: "г")
                    DecimalField(title: "  полиненасыщенные", value: $facts.polyunsaturatedFat, unit: "г")
                    DecimalField(title: "  трансжиры", value: $facts.transFat, unit: "г")
                    DecimalField(title: "Холестерин", value: $facts.cholesterolMg, unit: "мг")
                }

                Section("Углеводы") {
                    DecimalField(title: "Углеводы", value: $facts.carbohydrates, unit: "г")
                    DecimalField(title: "  сахара", value: $facts.sugars, unit: "г")
                    DecimalField(title: "  полиолы", value: $facts.polyols, unit: "г")
                    DecimalField(title: "  крахмал", value: $facts.starch, unit: "г")
                    DecimalField(title: "Клетчатка", value: $facts.fiber, unit: "г")
                }

                Section("Белки и соль") {
                    DecimalField(title: "Белки", value: $facts.protein, unit: "г")
                    DecimalField(title: "Соль", value: $facts.salt, unit: "г")
                    DecimalField(title: "Натрий", value: $facts.sodiumMg, unit: "мг")
                    if facts.salt == nil, let na = facts.sodiumMg, na > 0 {
                        Button("Соль из натрия: \(NutrientFormatter.precise(na * 2.5 / 1000)) г") { facts.salt = na * 2.5 / 1000 }
                            .font(.footnote)
                    }
                    DecimalField(title: "Алкоголь", value: $facts.alcohol, unit: "г")
                }

                Section {
                    ForEach(Array(facts.micronutrients.enumerated()), id: \.offset) { index, m in
                        HStack {
                            Text(m.title)
                            Spacer()
                            TextField("0", value: Binding<Double>(
                                get: { index < facts.micronutrients.count ? facts.micronutrients[index].amount : 0 },
                                set: { if index < facts.micronutrients.count { facts.micronutrients[index].amount = $0 } }
                            ), format: FloatingPointFormatStyle<Double>.number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            Text(m.unit).foregroundStyle(.secondary).frame(minWidth: 28, alignment: .leading)
                        }
                    }
                    .onDelete { offsets in facts.micronutrients.remove(atOffsets: offsets) }
                    Button { showMicroPicker = true } label: {
                        Label("Добавить витамин или минерал", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Витамины и минералы")
                } footer: {
                    if !facts.micronutrients.isEmpty {
                        Text("Значения на 100 \(basis.unitSymbol), как на упаковке.")
                    }
                }

                Section("Заметки") {
                    TextField("Например: без глютена, магазин…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let data = labelImage, let image = UIImage(data: data) {
                    Section("Фото этикетки") {
                        Button { showPhoto = true } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        Button("Удалить фото", role: .destructive) { labelImage = nil }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEdit ? "Продукт" : "Новый продукт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showMicroPicker) {
                MicronutrientPicker(existing: Set(facts.micronutrients.map { $0.key })) { micro in
                    facts.micronutrients.append(MicronutrientValue(key: micro.rawValue, amount: 0, unit: micro.unit))
                }
            }
            .sheet(isPresented: $showPhoto) {
                if let data = labelImage, let image = UIImage(data: data) {
                    PhotoViewer(image: image)
                } else {
                    ContentUnavailableView("Не удалось открыть фото", systemImage: "photo")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                load()
            }
        }
    }

    private func load() {
        switch mode {
        case .create(let draft):
            name = draft.name
            brand = draft.brand
            basis = draft.basis
            servingSize = draft.servingSize
            servingName = draft.servingName ?? ""
            facts = draft.facts
            notes = draft.notes
            reviewHint = draft.reviewHint
            modelInfo = draft.modelInfo
            labelImage = draft.labelImage
        case .edit(let product):
            name = product.name
            brand = product.brand
            basis = product.basis
            servingSize = product.servingSize
            servingName = product.servingName ?? ""
            facts = product.facts
            notes = product.notes
            labelImage = product.labelImage
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let cleanFacts = facts.rounded()
        switch mode {
        case .create:
            let product = Product(name: cleanName, brand: brand.trimmingCharacters(in: .whitespaces), basis: basis, facts: cleanFacts,
                                  servingSize: servingSize, servingName: servingName.isEmpty ? nil : servingName, notes: notes,
                                  source: reviewHint.isEmpty && labelImage == nil ? "manual" : "photo", labelImage: labelImage)
            context.insert(product)
            dismiss()
            onSaved?(product)
        case .edit(let product):
            product.name = cleanName
            product.brand = brand.trimmingCharacters(in: .whitespaces)
            product.basis = basis
            product.servingSize = servingSize
            product.servingName = servingName.isEmpty ? nil : servingName
            product.facts = cleanFacts
            product.notes = notes
            product.labelImage = labelImage
            product.updatedAt = Date()
            dismiss()
            onSaved?(product)
        }
    }
}

/// Выбор витамина/минерала из списка Регламента 1169/2011.
struct MicronutrientPicker: View {
    let existing: Set<String>
    let onPick: (Micronutrient) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Витамины") {
                    ForEach(Micronutrient.allCases.filter { $0.isVitamin }) { m in row(m) }
                }
                Section("Минералы") {
                    ForEach(Micronutrient.allCases.filter { !$0.isVitamin }) { m in row(m) }
                }
            }
            .navigationTitle("Добавить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }

    private func row(_ m: Micronutrient) -> some View {
        Button {
            onPick(m)
            dismiss()
        } label: {
            HStack {
                Text(m.title)
                Spacer()
                Text("NRV \(NutrientFormatter.auto(m.nrv)) \(m.unit)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(existing.contains(m.rawValue))
    }
}

struct PhotoViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
    }
}
