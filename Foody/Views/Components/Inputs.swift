import SwiftUI
import FoodyCore

/// Поле ввода числа (принимает запятую и точку). Пустое поле = nil.
struct DecimalField: View {
    let title: String
    @Binding var value: Double?
    var unit: String? = nil
    var placeholder = "—"

    @State private var text = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 70)
                .onChange(of: text) { _, newValue in
                    let parsed = NutrientFormatter.parse(newValue)
                    if parsed != value { value = parsed }
                }
                .onChange(of: value) { _, newValue in
                    if NutrientFormatter.parse(text) != newValue {
                        text = newValue.map { NutrientFormatter.precise($0) } ?? ""
                    }
                }
                .onAppear {
                    text = value.map { NutrientFormatter.precise($0) } ?? ""
                }
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, alignment: .leading)
            }
        }
    }
}

/// Обязательное числовое поле (Double без optional).
struct RequiredDecimalField: View {
    let title: String
    @Binding var value: Double
    var unit: String? = nil

    var body: some View {
        DecimalField(title: title, value: Binding(
            get: { value },
            set: { value = $0 ?? 0 }
        ), unit: unit, placeholder: "0")
    }
}

struct CategoryPicker: View {
    @Binding var category: MealCategory

    var body: some View {
        Picker("Приём пищи", selection: $category) {
            ForEach(MealCategory.allCases) { c in
                Text(c.title).tag(c)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Быстрые кнопки количества.
struct AmountChips: View {
    let options: [Double]
    let unit: String
    let onPick: (Double) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { v in
                    Button {
                        onPick(v)
                    } label: {
                        Text("\(NutrientFormatter.grams(v)) \(unit)")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.accent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
    }
}
