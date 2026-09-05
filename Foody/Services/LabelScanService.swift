import Foundation
import UIKit
import FoodyCore

/// Черновик продукта, полученный из фото: заполняет форму продукта, пользователь проверяет и сохраняет.
struct ProductDraft: Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var brand: String = ""
    var basis: MeasureBasis = .grams
    var servingSize: Double?
    var servingName: String?
    var facts: NutritionFacts = NutritionFacts()
    var notes: String = ""
    var reviewHint: String = ""
    var labelImage: Data?
    var modelInfo: String = ""

    init() {}

    init(outcome: LabelParseOutcome, image: Data?) {
        let r = outcome.result
        name = r.productName ?? ""
        brand = r.brand ?? ""
        basis = r.measureBasis
        servingSize = r.servingSizeG
        servingName = r.servingDescription
        facts = r.nutritionFacts
        reviewHint = r.reviewHint
        labelImage = image
        var info = "Модель: \(outcome.model), \(String(format: "%.1f", outcome.latency)) с"
        if let i = outcome.inputTokens, let o = outcome.outputTokens { info += ", токены \(i)/\(o)" }
        modelInfo = info
    }
}

/// Оркестрация: фото → JPEG → модель → черновик.
enum LabelScanService {
    static func scan(image: UIImage, settings: AppSettings) async throws -> ProductDraft {
        guard settings.hasKey else { throw LabelParseError.missingAPIKey }
        guard let jpeg = ImageProcessing.prepareForUpload(image) else { throw LabelParseError.invalidImage }
        let parser = LabelParserFactory.make(config: settings.parserConfig)
        let outcome = try await parser.parse(imageJPEG: jpeg)
        let keep = settings.keepLabelPhoto ? ImageProcessing.thumbnail(image) : nil
        return ProductDraft(outcome: outcome, image: keep)
    }
}
