import Foundation

/// Распознавание через Anthropic Messages API со structured outputs (`output_config.format`).
public struct AnthropicLabelParser: LabelParsing {
    public var config: LabelParserConfig
    public var transport: HTTPTransport
    public var endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(config: LabelParserConfig, transport: HTTPTransport = HTTPTransport()) {
        self.config = config
        self.transport = transport
    }

    /// Тело запроса (отдельно — для тестов). `effort` применяется только к моделям, которые его поддерживают (не Haiku).
    public static func requestBody(model: String, imageJPEG: Data, effort: String?) -> [String: Any] {
        var outputConfig: [String: Any] = [
            "format": ["type": "json_schema", "schema": LabelParseSpec.schemaObject] as [String: Any]
        ]
        if let effort = effort, !effort.isEmpty, !model.hasPrefix("claude-haiku") {
            outputConfig["effort"] = effort
        }
        return [
            "model": model,
            "max_tokens": 4000,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg",
                                                  "data": imageJPEG.base64EncodedString()] as [String: Any]] as [String: Any],
                    ["type": "text", "text": LabelParseSpec.instruction] as [String: Any]
                ] as [Any]
            ] as [String: Any]],
            "output_config": outputConfig
        ]
    }

    public static func extract(response data: Data) throws -> (text: String, inputTokens: Int?, outputTokens: Int?) {
        guard let obj = JSONHelpers.object(data) else { throw LabelParseError.decoding("not a JSON object") }
        if (obj["stop_reason"] as? String) == "refusal" {
            let details = (obj["stop_details"] as? [String: Any])?["explanation"] as? String ?? "refusal"
            throw LabelParseError.refusal(details)
        }
        let text = ((obj["content"] as? [[String: Any]]) ?? [])
            .first { ($0["type"] as? String) == "text" }?["text"] as? String
        guard let t = text, !t.isEmpty else { throw LabelParseError.emptyResponse }
        let usage = obj["usage"] as? [String: Any]
        return (t, usage?["input_tokens"] as? Int, usage?["output_tokens"] as? Int)
    }

    public func parse(imageJPEG: Data) async throws -> LabelParseOutcome {
        guard !config.apiKey.isEmpty else { throw LabelParseError.missingAPIKey }
        guard !imageJPEG.isEmpty else { throw LabelParseError.invalidImage }
        let body = try JSONHelpers.encode(Self.requestBody(model: config.model, imageJPEG: imageJPEG, effort: config.effort))
        let started = Date()
        let (status, data) = try await transport.post(
            url: endpoint,
            headers: ["x-api-key": config.apiKey, "anthropic-version": "2023-06-01", "Content-Type": "application/json"],
            body: body)
        let latency = Date().timeIntervalSince(started)
        guard status == 200 else { throw LabelParseError.http(status: status, message: JSONHelpers.errorMessage(data)) }
        let (text, inTok, outTok) = try Self.extract(response: data)
        do {
            let result = try LabelParseResult.decode(jsonText: text)
            return LabelParseOutcome(result: result, model: config.model, latency: latency, inputTokens: inTok,
                                     outputTokens: outTok, rawText: text)
        } catch let e as LabelParseError {
            throw e
        } catch {
            throw LabelParseError.decoding(error.localizedDescription)
        }
    }
}
