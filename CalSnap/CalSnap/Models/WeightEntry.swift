import Foundation
import SwiftData

/// A single body-weight measurement.
@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var kg: Double

    init(kg: Double, date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.kg = kg
    }
}
