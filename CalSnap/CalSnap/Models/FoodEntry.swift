import Foundation
import SwiftData

// MARK: - Meal categories

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .breakfast: return "meal.breakfast"
        case .lunch:     return "meal.lunch"
        case .dinner:    return "meal.dinner"
        case .snack:     return "meal.snack"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        case .snack:     return "carrot.fill"
        }
    }

    /// Reasonable default based on the current hour.
    static func suggested(for date: Date = .now) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11:  return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default:      return .snack
        }
    }
}

// MARK: - A single recognized food item within a meal

struct FoodItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var quantity: String          // e.g. "1 bowl", "150 g"
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    /// Model's confidence 0…1 for transparency in the UI.
    var confidence: Double = 0.8
}

// MARK: - Persisted meal entry

@Model
final class FoodEntry {
    var id: UUID
    var title: String
    var mealRaw: String
    var date: Date
    /// Locally stored image (compressed JPEG) for the meal thumbnail.
    @Attribute(.externalStorage) var imageData: Data?
    var note: String

    // Cached totals (sum of items) for fast queries.
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double

    /// Recognized items encoded as JSON.
    var itemsData: Data?

    /// Whether this entry was written to Apple Health.
    var syncedToHealth: Bool

    init(title: String,
         meal: MealType,
         date: Date = .now,
         items: [FoodItem] = [],
         imageData: Data? = nil,
         note: String = "") {
        self.id = UUID()
        self.title = title
        self.mealRaw = meal.rawValue
        self.date = date
        self.imageData = imageData
        self.note = note
        self.syncedToHealth = false
        self.itemsData = try? JSONEncoder().encode(items)
        self.calories = items.reduce(0) { $0 + $1.calories }
        self.proteinGrams = items.reduce(0) { $0 + $1.proteinGrams }
        self.carbsGrams = items.reduce(0) { $0 + $1.carbsGrams }
        self.fatGrams = items.reduce(0) { $0 + $1.fatGrams }
    }

    var meal: MealType {
        get { MealType(rawValue: mealRaw) ?? .snack }
        set { mealRaw = newValue.rawValue }
    }

    var items: [FoodItem] {
        get {
            guard let itemsData,
                  let decoded = try? JSONDecoder().decode([FoodItem].self, from: itemsData)
            else { return [] }
            return decoded
        }
        set {
            itemsData = try? JSONEncoder().encode(newValue)
            calories = newValue.reduce(0) { $0 + $1.calories }
            proteinGrams = newValue.reduce(0) { $0 + $1.proteinGrams }
            carbsGrams = newValue.reduce(0) { $0 + $1.carbsGrams }
            fatGrams = newValue.reduce(0) { $0 + $1.fatGrams }
        }
    }
}
