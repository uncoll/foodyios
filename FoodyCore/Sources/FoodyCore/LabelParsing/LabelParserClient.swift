import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Поставщик модели.
public enum LLMProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "openai"
    case anthropic = "anthropic"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic (Claude)"
        }
    }

    public var keyPlaceholder: String {
        switch self {
        case .openAI: return "sk-..."
        case .anthropic: return "sk-ant-..."
        }
    }

    public var consoleURL: String {
        switch self {
        case .openAI: return "https://platform.openai.com/api-keys"
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        }
    }
}

/// Настройки распознавания: поставщик, модель, ключ, усилие рассуждения.
public struct LabelParserConfig: Equatable, Sendable {
    public var provider: LLMProvider
    public var model: String
    public var apiKey: String
    /// Для reasoning-моделей OpenAI (`low` по умолчанию — быстро и дёшево) и `output_config.effort` у Claude.
    public var effort: String?

    public init(provider: LLMProvider, model: String, apiKey: String, effort: String? = "low") {
        self.provider = provider
        self.model = model
        self.apiKey = apiKey
        self.effort = effort
    }
}

public enum LabelParseError: Error, LocalizedError, Equatable, Sendable {
    case missingAPIKey
    case invalidImage
    case network(String)
    case http(status: Int, message: String)
    case emptyResponse
    case refusal(String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Не задан API-ключ. Добавьте его в Настройках."
        case .invalidImage: return "Не удалось подготовить изображение."
        case .network(let m): return "Ошибка сети: \(m)"
        case .http(let status, let message):
            switch status {
            case 401: return "Ключ отклонён (401). Проверьте API-ключ."
            case 403: return "Доступ запрещён (403): \(message)"
            case 404: return "Модель не найдена (404): \(message)"
            case 429: return "Превышен лимит запросов (429). Попробуйте позже."
            default: return "Ошибка сервера \(status): \(message)"
            }
        case .emptyResponse: return "Модель вернула пустой ответ."
        case .refusal(let m): return "Модель отказалась отвечать: \(m)"
        case .decoding(let m): return "Не удалось разобрать ответ модели: \(m)"
        }
    }
}

/// Результат вызова с диагностикой (латентность, токены) — показываем в интерфейсе и логах.
public struct LabelParseOutcome: Sendable {
    public var result: LabelParseResult
    public var model: String
    public var latency: TimeInterval
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var rawText: String

    public init(result: LabelParseResult, model: String, latency: TimeInterval, inputTokens: Int?, outputTokens: Int?, rawText: String) {
        self.result = result
        self.model = model
        self.latency = latency
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.rawText = rawText
    }
}

/// Общий интерфейс распознавателя.
public protocol LabelParsing: Sendable {
    func parse(imageJPEG: Data) async throws -> LabelParseOutcome
}

/// Минимальный HTTP-транспорт (URLSession; работает и на Linux через FoundationNetworking).
public struct HTTPTransport: Sendable {
    public var timeout: TimeInterval

    public init(timeout: TimeInterval = 120) {
        self.timeout = timeout
    }

    public func post(url: URL, headers: [String: String], body: Data) async throws -> (status: Int, data: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = timeout
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let session = URLSession.shared
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: LabelParseError.network(error.localizedDescription))
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                continuation.resume(returning: (status, data ?? Data()))
            }
            task.resume()
        }
    }
}

/// Утилиты для разбора тел ответов.
enum JSONHelpers {
    static func object(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func errorMessage(_ data: Data) -> String {
        guard let obj = object(data) else { return String(decoding: data.prefix(300), as: UTF8.self) }
        if let err = obj["error"] as? [String: Any] {
            return (err["message"] as? String) ?? (err["type"] as? String) ?? "\(err)"
        }
        return (obj["message"] as? String) ?? String(decoding: data.prefix(300), as: UTF8.self)
    }

    static func encode(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

/// Фабрика распознавателей.
public enum LabelParserFactory {
    public static func make(config: LabelParserConfig, transport: HTTPTransport = HTTPTransport()) -> any LabelParsing {
        switch config.provider {
        case .openAI: return OpenAILabelParser(config: config, transport: transport)
        case .anthropic: return AnthropicLabelParser(config: config, transport: transport)
        }
    }
}
