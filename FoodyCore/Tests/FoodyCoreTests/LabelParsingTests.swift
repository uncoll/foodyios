import XCTest
@testable import FoodyCore

final class LabelParsingTests: XCTestCase {
    let sample = """
    {"product_name": null, "brand": null, "basis": "per_100g", "serving_size_g": 30, "serving_description": "1 portion (30 g)",
     "energy_kcal": 372, "energy_kj": 1560, "fat_g": 7.0, "saturated_fat_g": 1.3, "monounsaturated_fat_g": null,
     "polyunsaturated_fat_g": null, "trans_fat_g": null, "cholesterol_mg": null, "carbohydrates_g": 58.7, "sugars_g": 0.7,
     "polyols_g": null, "starch_g": null, "fiber_g": 10.0, "protein_g": 13.5, "salt_g": 0.01, "sodium_mg": null, "alcohol_g": null,
     "micronutrients": [{"name": "iron", "amount": 4.2, "unit": "mg"}, {"name": "Vitamin B1", "amount": 0.5, "unit": "mg"}],
     "label_language": "de", "values_source": "per_100_column", "notes": "salt printed as <0,01 g", "confidence": "high"}
    """

    func testDecodeSampleAndConvert() throws {
        let r = try LabelParseResult.decode(jsonText: sample)
        XCTAssertEqual(r.energyKcal, 372)
        XCTAssertEqual(r.fiberG, 10)
        XCTAssertEqual(r.measureBasis, .grams)
        XCTAssertEqual(r.confidence, "high")
        let f = r.nutritionFacts
        XCTAssertEqual(f.kcal, 372)
        XCTAssertEqual(f.salt, 0.01)
        XCTAssertNil(f.sodiumMg)
        XCTAssertEqual(f.micronutrients.count, 2)
        XCTAssertEqual(f.micronutrients.map { $0.key }.sorted(), ["iron", "thiamin"])
        XCTAssertTrue(r.hasMainValues)
        XCTAssertTrue(r.reviewHint.contains("высокая"))
    }

    func testDecodeTolerantToFencesAndStrings() throws {
        let fenced = "```json\n{\"basis\": \"per_100ml\", \"energy_kcal\": \"43\", \"sugars_g\": \"10,5\", \"micronutrients\": []}\n```"
        let r = try LabelParseResult.decode(jsonText: fenced)
        XCTAssertEqual(r.measureBasis, .milliliters)
        XCTAssertEqual(r.energyKcal, 43)
        XCTAssertEqual(r.sugarsG, 10.5)
        XCTAssertFalse(r.hasMainValues == false)
    }

    func testSchemaIsValidJSONAndMatchesCodingKeys() throws {
        let schema = LabelParseSpec.schemaObject
        XCTAssertEqual(schema["type"] as? String, "object")
        let required = schema["required"] as? [String] ?? []
        XCTAssertEqual(required.count, 27)
        let props = schema["properties"] as? [String: Any] ?? [:]
        XCTAssertEqual(Set(props.keys), Set(required), "все свойства обязательны (strict mode)")
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
        // ключи схемы совпадают с CodingKeys результата
        let keys = ["product_name", "brand", "basis", "serving_size_g", "serving_description", "energy_kcal", "energy_kj",
                    "fat_g", "saturated_fat_g", "monounsaturated_fat_g", "polyunsaturated_fat_g", "trans_fat_g", "cholesterol_mg",
                    "carbohydrates_g", "sugars_g", "polyols_g", "starch_g", "fiber_g", "protein_g", "salt_g", "sodium_mg",
                    "alcohol_g", "micronutrients", "label_language", "values_source", "notes", "confidence"]
        XCTAssertEqual(Set(keys), Set(required))
        XCTAssertFalse(LabelParseSpec.instruction.isEmpty)
        XCTAssertTrue(LabelParseSpec.instruction.contains("PER 100 g"))
    }

    func testOpenAIRequestBody() throws {
        let image = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let body = OpenAILabelParser.requestBody(model: "gpt-5.6-luna", imageJPEG: image, effort: "low")
        XCTAssertEqual(body["model"] as? String, "gpt-5.6-luna")
        XCTAssertEqual((body["reasoning"] as? [String: Any])?["effort"] as? String, "low")
        let text = body["text"] as? [String: Any]
        let format = text?["format"] as? [String: Any]
        XCTAssertEqual(format?["type"] as? String, "json_schema")
        XCTAssertEqual(format?["strict"] as? Bool, true)
        XCTAssertNotNil(format?["schema"])
        let input = body["input"] as? [[String: Any]]
        let content = input?.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.count, 2)
        XCTAssertTrue((content?[1]["image_url"] as? String ?? "").hasPrefix("data:image/jpeg;base64,/9j/"))
        let plain = OpenAILabelParser.requestBody(model: "gpt-4.1-mini", imageJPEG: image, effort: "low")
        XCTAssertNil(plain["reasoning"], "не reasoning-модель — параметр не отправляем")
        XCTAssertNoThrow(try JSONHelpers.encode(body))
    }

    func testOpenAIResponseExtraction() throws {
        let response = """
        {"id": "resp_1", "status": "completed", "output": [
            {"type": "reasoning", "summary": []},
            {"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "{\\"basis\\": \\"per_100g\\", \\"energy_kcal\\": 100, \\"micronutrients\\": []}"}]}
         ], "usage": {"input_tokens": 1200, "output_tokens": 300}}
        """
        let (text, inTok, outTok) = try OpenAILabelParser.extract(response: Data(response.utf8))
        XCTAssertEqual(inTok, 1200)
        XCTAssertEqual(outTok, 300)
        let r = try LabelParseResult.decode(jsonText: text)
        XCTAssertEqual(r.energyKcal, 100)
        let refusal = #"{"status": "completed", "output": [{"type": "message", "content": [{"type": "refusal", "refusal": "no"}]}]}"#
        XCTAssertThrowsError(try OpenAILabelParser.extract(response: Data(refusal.utf8))) { error in
            XCTAssertEqual(error as? LabelParseError, .refusal("no"))
        }
    }

    func testAnthropicRequestBodyAndResponse() throws {
        let image = Data([0xFF, 0xD8, 0xFF])
        let body = AnthropicLabelParser.requestBody(model: "claude-haiku-4-5", imageJPEG: image, effort: "low")
        XCTAssertEqual(body["model"] as? String, "claude-haiku-4-5")
        let oc = body["output_config"] as? [String: Any]
        XCTAssertNil(oc?["effort"], "Haiku не поддерживает effort")
        XCTAssertEqual((oc?["format"] as? [String: Any])?["type"] as? String, "json_schema")
        let messages = body["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["type"] as? String, "image")
        XCTAssertEqual(content?.last?["type"] as? String, "text")
        let sonnet = AnthropicLabelParser.requestBody(model: "claude-sonnet-5", imageJPEG: image, effort: "low")
        XCTAssertEqual((sonnet["output_config"] as? [String: Any])?["effort"] as? String, "low")

        let response = #"{"content": [{"type": "text", "text": "{\"basis\": \"per_100ml\", \"energy_kcal\": 43, \"micronutrients\": []}"}], "stop_reason": "end_turn", "usage": {"input_tokens": 2000, "output_tokens": 250}}"#
        let (text, inTok, outTok) = try AnthropicLabelParser.extract(response: Data(response.utf8))
        XCTAssertEqual(inTok, 2000)
        XCTAssertEqual(outTok, 250)
        XCTAssertEqual(try LabelParseResult.decode(jsonText: text).energyKcal, 43)
        let refusal = #"{"content": [], "stop_reason": "refusal", "stop_details": {"type": "refusal", "explanation": "policy"}}"#
        XCTAssertThrowsError(try AnthropicLabelParser.extract(response: Data(refusal.utf8)))
    }

    func testFactoryAndErrors() async {
        let parser = LabelParserFactory.make(config: LabelParserConfig(provider: .openAI, model: "gpt-5.6-luna", apiKey: ""))
        do {
            _ = try await parser.parse(imageJPEG: Data([1, 2, 3]))
            XCTFail("должна быть ошибка отсутствующего ключа")
        } catch {
            XCTAssertEqual(error as? LabelParseError, .missingAPIKey)
        }
        XCTAssertEqual(LabelParseError.http(status: 401, message: "x").errorDescription?.contains("401"), true)
        XCTAssertEqual(ModelCatalog.option(provider: .anthropic, modelID: "claude-haiku-4-5")?.title, "Claude Haiku 4.5")
        XCTAssertGreaterThan(ModelCatalog.recommended.estimatedCostPerScanUSD, 0)
    }
}
