import Foundation
import SwiftData
import FoodyCore

/// Дневные цели, действующие с даты `effectiveFrom` (история сохраняется — статистика прошлых недель считается по тогдашним целям).
@Model
final class TargetPlan {
    var uuid: UUID = UUID()
    var effectiveFrom: Date = Date()
    var kcal: Double = 2000
    var protein: Double = 110
    var fat: Double = 70
    var carbs: Double = 230
    var fiberMin: Double?
    var sugarsMax: Double?
    var saturatedFatMax: Double?
    var saltMax: Double?

    init(effectiveFrom: Date, targets: DailyTargets) {
        self.uuid = UUID()
        self.effectiveFrom = Calendar.current.startOfDay(for: effectiveFrom)
        self.kcal = targets.kcal
        self.protein = targets.protein
        self.fat = targets.fat
        self.carbs = targets.carbs
        self.fiberMin = targets.fiberMin
        self.sugarsMax = targets.sugarsMax
        self.saturatedFatMax = targets.saturatedFatMax
        self.saltMax = targets.saltMax
    }

    var targets: DailyTargets {
        get {
            DailyTargets(kcal: kcal, protein: protein, fat: fat, carbs: carbs, fiberMin: fiberMin, sugarsMax: sugarsMax,
                         saturatedFatMax: saturatedFatMax, saltMax: saltMax)
        }
        set {
            kcal = newValue.kcal
            protein = newValue.protein
            fat = newValue.fat
            carbs = newValue.carbs
            fiberMin = newValue.fiberMin
            sugarsMax = newValue.sugarsMax
            saturatedFatMax = newValue.saturatedFatMax
            saltMax = newValue.saltMax
        }
    }

    var snapshot: TargetSnapshot { TargetSnapshot(effectiveFrom: effectiveFrom, targets: targets) }
}
