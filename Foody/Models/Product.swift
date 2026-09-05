import Foundation
import SwiftData
import FoodyCore

/// Продукт в локальной базе: значения на 100 г/мл + сервисные поля.
@Model
final class Product {
    var uuid: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var barcode: String?
    /// "g" или "ml" (см. `MeasureBasis`).
    var basisRaw: String = MeasureBasis.grams.rawValue
    /// Размер стандартной порции в г/мл (если указан на упаковке).
    var servingSize: Double?
    var servingName: String?
    /// Денормализованные значения на 100 г/мл — для быстрых списков и сортировки.
    var kcal: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    /// Полная пищевая ценность на 100 г/мл (JSON `NutritionFacts`).
    var factsData: Data = Data()
    var notes: String = ""
    var isFavorite: Bool = false
    /// "manual" | "photo"
    var sourceRaw: String = "manual"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var usageCount: Int = 0
    var lastUsedAt: Date?
    @Attribute(.externalStorage) var labelImage: Data?

    init(name: String, brand: String = "", basis: MeasureBasis = .grams, facts: NutritionFacts,
         servingSize: Double? = nil, servingName: String? = nil, notes: String = "", source: String = "manual",
         labelImage: Data? = nil) {
        self.uuid = UUID()
        self.name = name
        self.brand = brand
        self.basisRaw = basis.rawValue
        self.servingSize = servingSize
        self.servingName = servingName
        self.notes = notes
        self.sourceRaw = source
        self.labelImage = labelImage
        self.createdAt = Date()
        self.updatedAt = Date()
        self.factsData = Data()
        self.facts = facts
    }

    var basis: MeasureBasis {
        get { MeasureBasis(rawValue: basisRaw) ?? .grams }
        set { basisRaw = newValue.rawValue }
    }

    var facts: NutritionFacts {
        get { (try? JSONDecoder().decode(NutritionFacts.self, from: factsData)) ?? NutritionFacts() }
        set {
            factsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            kcal = newValue.kcal
            protein = newValue.proteinValue
            fat = newValue.fatValue
            carbs = newValue.carbsValue
        }
    }

    var isFromPhoto: Bool { sourceRaw == "photo" }

    /// «Бренд · 250 ккал» — подзаголовок в списках.
    var subtitle: String {
        var parts: [String] = []
        if !brand.isEmpty { parts.append(brand) }
        parts.append("\(NutrientFormatter.kcal(kcal)) ккал \(basis.per100Title)")
        return parts.joined(separator: " · ")
    }

    func markUsed() {
        usageCount += 1
        lastUsedAt = Date()
    }
}
