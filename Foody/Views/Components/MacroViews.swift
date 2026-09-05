import SwiftUI
import FoodyCore

/// Кольцо прогресса по калориям с числом внутри.
struct MacroRing: View {
    let value: Double
    let target: Double?
    var lineWidth: CGFloat = 12
    var size: CGFloat = 132

    private var fraction: Double {
        guard let t = target, t > 0 else { return 0 }
        return min(value / t, 1)
    }

    private var isOver: Bool {
        guard let t = target, t > 0 else { return false }
        return value > t * 1.05
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.accent.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(isOver ? Theme.over : Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: fraction)
            VStack(spacing: 2) {
                Text(NutrientFormatter.kcal(value))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let t = target {
                    Text("из \(NutrientFormatter.kcal(t))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("ккал")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Калории: \(NutrientFormatter.kcal(value))")
    }
}

/// Тонкая полоска прогресса по макронутриенту.
struct MacroBar: View {
    let macro: Macro
    let value: Double
    let target: Double?
    var compact = false

    private var fraction: Double {
        guard let t = target, t > 0 else { return 0 }
        return min(value / t, 1)
    }

    private var over: Bool {
        guard let t = target, t > 0 else { return false }
        return value > t * 1.05
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(macro.title)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText)
                    .font(compact ? .caption.monospacedDigit() : .subheadline.monospacedDigit())
                    .foregroundStyle(over ? Theme.over : .primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.color(for: macro).opacity(0.15))
                    Capsule()
                        .fill(over ? Theme.over : Theme.color(for: macro))
                        .frame(width: max(0, geo.size.width * fraction))
                        .animation(.easeOut(duration: 0.4), value: fraction)
                }
            }
            .frame(height: compact ? 5 : 7)
        }
    }

    private var valueText: String {
        let v = macro == .kcal ? NutrientFormatter.kcal(value) : NutrientFormatter.grams(value)
        if let t = target {
            let tt = macro == .kcal ? NutrientFormatter.kcal(t) : NutrientFormatter.grams(t)
            return "\(v) / \(tt) \(macro.unit)"
        }
        return "\(v) \(macro.unit)"
    }
}

/// Строка «Показатель … значение» для таблиц пищевой ценности.
struct NutrientRow: View {
    let title: String
    let value: Double?
    let unit: String
    var indent = false
    var emphasized = false

    var body: some View {
        HStack {
            Text(title)
                .font(emphasized ? .body.weight(.medium) : .body)
                .foregroundStyle(indent ? .secondary : .primary)
                .padding(.leading, indent ? 16 : 0)
            Spacer()
            Text(value.map { NutrientFormatter.withUnit($0, unit: unit) } ?? "—")
                .font(.body.monospacedDigit())
                .foregroundStyle(value == nil ? .tertiary : .primary)
        }
    }
}

/// Компактная строка Б/Ж/У с цветными точками.
struct MacroSummaryLine: View {
    let facts: NutritionFacts
    var showKcal = true

    var body: some View {
        HStack(spacing: 10) {
            if showKcal {
                Text("\(NutrientFormatter.kcal(facts.kcal)) ккал")
                    .font(.subheadline.weight(.medium).monospacedDigit())
            }
            ForEach([Macro.protein, .fat, .carbs]) { m in
                HStack(spacing: 3) {
                    Circle().fill(Theme.color(for: m)).frame(width: 6, height: 6)
                    Text("\(m.shortTitle) \(NutrientFormatter.grams(m.value(in: facts)))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Бейдж «Перебор / Недобор / В норме».
struct BalanceBadge: View {
    let balance: Balance
    let delta: Double
    let unit: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: balance == .over ? "arrow.up" : (balance == .under ? "arrow.down" : "checkmark"))
            Text(balance == .onTarget ? balance.title : "\(balance.title) \(deltaText)")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.color(for: balance).opacity(0.14), in: Capsule())
        .foregroundStyle(Theme.color(for: balance))
    }

    private var deltaText: String {
        let v = abs(delta)
        return unit == "ккал" ? "\(NutrientFormatter.kcal(v)) ккал" : "\(NutrientFormatter.grams(v)) \(unit)"
    }
}
