import Foundation
import SwiftData

// MARK: - Cloud snapshot DTOs (what we back up / restore)

struct FoodDTO: Codable {
    var id: String
    var title: String
    var meal: String
    var date: Date
    var note: String
    var items: [FoodItem]

    init(_ e: FoodEntry) {
        id = e.id.uuidString
        title = e.title
        meal = e.mealRaw
        date = e.date
        note = e.note
        items = e.items
    }

    func makeEntry() -> FoodEntry {
        FoodEntry(title: title,
                  meal: MealType(rawValue: meal) ?? .snack,
                  date: date,
                  items: items,
                  note: note)
    }
}

struct WeightDTO: Codable {
    var date: Date
    var kg: Double
    init(_ w: WeightEntry) { date = w.date; kg = w.kg }
    func makeEntry() -> WeightEntry { WeightEntry(kg: kg, date: date) }
}

/// Everything we sync to the cloud (images stay on-device to keep it light).
struct CloudSnapshot: Codable {
    var version = 1
    var updatedAt = Date()
    var foods: [FoodDTO] = []
    var weights: [WeightDTO] = []
    var profile: UserProfile = UserProfile()
    var burnedByDay: [String: Int] = [:]
    var waterByDay: [String: Int] = [:]
    var waterGoalML: Int = 2000
}
