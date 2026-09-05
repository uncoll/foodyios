import Foundation

/// Распознавание через OpenAI Responses API со structured outputs (json_schema, strict).
public struct OpenAILabelParser: LabelParsing {
    public var config: LabelParserConfig
    public var transport: HTTPTransport
    public var endpoint = URL(string: "https://api.openai.com/v1/responses")!

    public init(config: LabelParserConfig, transport: HTTPTransport = HTTPTransport()) {
        self.config = config
        self.transport = transport
    }

    /// Модели с рассуждением принимают `reasoning.effort`; для остальных параметр не отправляем.
    public static func isReasoningModel(_ model: String) -> Bool {
        model.hasPrefix("gpt-5") || model.hasPrefix("o1") || model.hasPrefix("o3") || model.hasPrefix("o4")
    }

    /// Тело запроса (отдельно — для тестов).
    public static func requestBody(model: String, imageJPEG: Data, effort: String?, detail: String = "high") -> [String: Any] {
        let dataURL = "data:image/jpeg;base64," + imageJPEG.base64EncodedString()
        var body: [String: Any] = [
            "model": model,
            "input": [[
                "role": "user",
                "content": [
                    ["type": "input_text", "text": LabelParseSpec.instruction],
                    ["type": "input_image", "image_url": dataURL, "detail": detail]
                ]
            ]],
            "text": ["format": [
                "type": "json_schema",
                "name": LabelParseSpec.schemaName,
                "strict": true,
                "schema": LabelParseSpec.schemaObject
            ]],
            "max_output_tokens": 4000,
            "store": false
        ]
        if isReasoningModel(model), let effort = effort, !effort.isEmpty {
            body["reasoning"] = ["effort": effort]
        }
        return body
    }

    /// Извлекает текст ответа и usage из тела Responses API.
    public static func extract(response data: Data) throws -> (text: String, inputTokens: Int?, outputTokens: Int?) {
        guard let obj = JSONHelpers.object(data) else { throw LabelParseError.decoding("not a JSON object") }
        var text: String? = nil
        var refusal: String? = nil
        for item in (obj["output"] as? [[String: Any]]) ?? [] where (item["type"] as? String) == "message" {
            for part in (item["content"] as? [[String: Any]]) ?? [] {
                switch part["type"] as? String {
                case "output_text": text = part["text"] as? String
                case "refusal": refusal = part["refusal"] as? String
                default: break
                }
            }
        }
        if text == nil, let output = obj["output_text"] as? String { text = output }
        let usage = obj["usage"] as? [String: Any]
        if let r = refusal, text == nil { throw LabelParseError.refusal(r) }
        guard let t = text, !t.isEmpty else {
            let status = obj["status"] as? String ?? "?"
            let details = (obj["incomplete_details"] as? [String: Any])?["reason"] as? String ?? ""
            throw LabelParseError.emptyResponseError(details: "status=\(status) \(details)")
        }
        return (t, usage?["input_tokens"] as? Int, usage?["output_tokens"] as? Int)
    }

    public func parse(imageJPEG: Data) async throws -> LabelParseOutcome {
        guard !config.apiKey.isEmpty else { throw LabelParseError.missingAPIKey }
        guard !imageJPEG.isEmpty else { throw LabelParseError.invalidImage }
        let body = try JSONHelpers.encode(Self.requestBody(model: config.model, imageJPEG: imageJPEG, effort: config.effort))
        let started = Date()
        let (status, data) = try await transport.post(
            url: endpoint,
            headers: ["Authorization": "Bearer \(config.apiKey)", "Content-Type": "application/json"],
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

extension LabelParseError {
    /// Пустой ответ с диагностикой.
    static func emptyResponseError(details: String) -> LabelParseError {
        details.trimmingCharacters(in: .whitespaces).isEmpty ? .emptyResponse : .decoding("пустой ответ (\(details))")
    }
}
