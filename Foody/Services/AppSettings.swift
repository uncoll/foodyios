import Foundation
import SwiftUI
import FoodyCore

/// Настройки приложения (UserDefaults) + ключи (Keychain).
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var provider: LLMProvider {
        didSet { defaults.set(provider.rawValue, forKey: "ai.provider") }
    }
    var model: String {
        didSet { defaults.set(model, forKey: "ai.model") }
    }
    /// Усилие рассуждения: "" (по умолчанию модели), "low", "medium", "high".
    var effort: String {
        didSet { defaults.set(effort, forKey: "ai.effort") }
    }
    /// Сохранять фото этикетки в карточке продукта.
    var keepLabelPhoto: Bool {
        didSet { defaults.set(keepLabelPhoto, forKey: "scan.keepPhoto") }
    }
    var openAIKey: String {
        didSet { KeychainStore.set(openAIKey, for: "openai") }
    }
    var anthropicKey: String {
        didSet { KeychainStore.set(anthropicKey, for: "anthropic") }
    }
    /// Первый запуск завершён (создан план целей по умолчанию).
    var didFinishOnboarding: Bool {
        didSet { defaults.set(didFinishOnboarding, forKey: "app.onboarded") }
    }

    init() {
        let recommended = ModelCatalog.recommended
        provider = LLMProvider(rawValue: defaults.string(forKey: "ai.provider") ?? "") ?? recommended.provider
        model = defaults.string(forKey: "ai.model") ?? recommended.modelID
        effort = defaults.string(forKey: "ai.effort") ?? "low"
        keepLabelPhoto = defaults.object(forKey: "scan.keepPhoto") as? Bool ?? true
        openAIKey = KeychainStore.get("openai")
        anthropicKey = KeychainStore.get("anthropic")
        didFinishOnboarding = defaults.bool(forKey: "app.onboarded")
    }

    var currentKey: String {
        switch provider {
        case .openAI: return openAIKey
        case .anthropic: return anthropicKey
        }
    }

    var hasKey: Bool { !currentKey.isEmpty }

    var parserConfig: LabelParserConfig {
        LabelParserConfig(provider: provider, model: model, apiKey: currentKey, effort: effort.isEmpty ? nil : effort)
    }

    var currentOption: ModelOption? { ModelCatalog.option(provider: provider, modelID: model) }
}
