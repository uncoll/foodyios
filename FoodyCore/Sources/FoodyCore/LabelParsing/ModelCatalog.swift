import Foundation

/// Вариант модели для выбора в настройках. Цены — $ за 1 млн токенов (вход / выход), для ориентира.
public struct ModelOption: Identifiable, Equatable, Hashable, Sendable {
    public var provider: LLMProvider
    public var modelID: String
    public var title: String
    public var inputPrice: Double
    public var outputPrice: Double
    public var note: String

    public var id: String { "\(provider.rawValue):\(modelID)" }

    public init(provider: LLMProvider, modelID: String, title: String, inputPrice: Double, outputPrice: Double, note: String) {
        self.provider = provider
        self.modelID = modelID
        self.title = title
        self.inputPrice = inputPrice
        self.outputPrice = outputPrice
        self.note = note
    }

    /// Ориентировочная стоимость одного распознавания (фото ≈ 2 500 токенов + инструкция ≈ 700, ответ ≈ 350).
    public var estimatedCostPerScanUSD: Double {
        (3200 * inputPrice + 350 * outputPrice) / 1_000_000
    }

    /// «≈ 0,4 ¢ за фото».
    public var costLabel: String {
        let cents = estimatedCostPerScanUSD * 100
        if cents < 1 { return String(format: "≈ %.1f ¢ за фото", cents).replacingOccurrences(of: ".", with: ",") }
        return String(format: "≈ %.0f ¢ за фото", cents)
    }
}

/// Каталог поддерживаемых моделей (см. docs/model-analysis.md — результаты бенчмарка).
public enum ModelCatalog {
    public static let openAI: [ModelOption] = [
        ModelOption(provider: .openAI, modelID: "gpt-5.6-luna", title: "GPT-5.6 Luna", inputPrice: 0.2, outputPrice: 1.2,
                    note: "Самая дешёвая модель со зрением у OpenAI"),
        ModelOption(provider: .openAI, modelID: "gpt-5.6-terra", title: "GPT-5.6 Terra", inputPrice: 2.0, outputPrice: 12.0,
                    note: "Средний уровень GPT-5.6"),
        ModelOption(provider: .openAI, modelID: "gpt-5.6-sol", title: "GPT-5.6 Sol", inputPrice: 4.0, outputPrice: 20.0,
                    note: "Флагман OpenAI, лучшее зрение (промо-цена до 21.11.2026)"),
        ModelOption(provider: .openAI, modelID: "gpt-5-mini", title: "GPT-5 mini", inputPrice: 0.25, outputPrice: 2.0,
                    note: "Дешёвая reasoning-модель"),
        ModelOption(provider: .openAI, modelID: "gpt-4.1-mini", title: "GPT-4.1 mini", inputPrice: 0.4, outputPrice: 1.6,
                    note: "Без рассуждений, быстрая")
    ]

    public static let anthropic: [ModelOption] = [
        ModelOption(provider: .anthropic, modelID: "claude-haiku-4-5", title: "Claude Haiku 4.5", inputPrice: 1.0, outputPrice: 5.0,
                    note: "Самая быстрая и дешёвая модель Claude"),
        ModelOption(provider: .anthropic, modelID: "claude-sonnet-5", title: "Claude Sonnet 5", inputPrice: 2.0, outputPrice: 10.0,
                    note: "Баланс цены и качества"),
        ModelOption(provider: .anthropic, modelID: "claude-opus-5", title: "Claude Opus 5", inputPrice: 5.0, outputPrice: 25.0,
                    note: "Максимальная точность")
    ]

    public static func options(for provider: LLMProvider) -> [ModelOption] {
        switch provider {
        case .openAI: return openAI
        case .anthropic: return anthropic
        }
    }

    public static var all: [ModelOption] { openAI + anthropic }

    /// Рекомендация по умолчанию (по итогам бенчмарка).
    public static let recommended = anthropic[1]

    public static func option(provider: LLMProvider, modelID: String) -> ModelOption? {
        options(for: provider).first { $0.modelID == modelID }
    }
}
