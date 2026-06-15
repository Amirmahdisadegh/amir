import Foundation

/// A built-in common food with nutrition for one typical serving.
struct CommonFood: Identifiable, Hashable {
    let name: String
    let serving: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    var id: String { name }

    func asItem(servings: Double = 1) -> FoodItem {
        FoodItem(name: name,
                 quantity: servings == 1 ? serving : "\(servings.clean)× \(serving)",
                 calories: Int(Double(calories) * servings),
                 proteinGrams: protein * servings,
                 carbsGrams: carbs * servings,
                 fatGrams: fat * servings,
                 confidence: 1)
    }
}

private extension Double {
    var clean: String { self == rounded() ? String(Int(self)) : String(format: "%.1f", self) }
}

enum FoodDatabase {
    static let foods: [CommonFood] = [
        .init(name: "Apple", serving: "1 medium", calories: 95, protein: 0.5, carbs: 25, fat: 0.3),
        .init(name: "Banana", serving: "1 medium", calories: 105, protein: 1.3, carbs: 27, fat: 0.4),
        .init(name: "Orange", serving: "1 medium", calories: 62, protein: 1.2, carbs: 15, fat: 0.2),
        .init(name: "Egg", serving: "1 large", calories: 78, protein: 6.3, carbs: 0.6, fat: 5.3),
        .init(name: "Boiled Egg", serving: "1 large", calories: 78, protein: 6.3, carbs: 0.6, fat: 5.3),
        .init(name: "Omelet", serving: "2 eggs", calories: 220, protein: 14, carbs: 2, fat: 17),
        .init(name: "White Rice", serving: "1 cup cooked", calories: 205, protein: 4.3, carbs: 45, fat: 0.4),
        .init(name: "Brown Rice", serving: "1 cup cooked", calories: 216, protein: 5, carbs: 45, fat: 1.8),
        .init(name: "Bread", serving: "1 slice", calories: 80, protein: 3, carbs: 14, fat: 1),
        .init(name: "Whole Wheat Bread", serving: "1 slice", calories: 81, protein: 4, carbs: 14, fat: 1.1),
        .init(name: "Grilled Chicken Breast", serving: "100 g", calories: 165, protein: 31, carbs: 0, fat: 3.6),
        .init(name: "Chicken Kebab", serving: "1 skewer", calories: 250, protein: 26, carbs: 4, fat: 14),
        .init(name: "Beef Steak", serving: "150 g", calories: 350, protein: 38, carbs: 0, fat: 22),
        .init(name: "Salmon", serving: "100 g", calories: 208, protein: 20, carbs: 0, fat: 13),
        .init(name: "Tuna", serving: "100 g", calories: 132, protein: 28, carbs: 0, fat: 1),
        .init(name: "Greek Yogurt", serving: "1 cup", calories: 100, protein: 17, carbs: 6, fat: 0.7),
        .init(name: "Milk", serving: "1 cup", calories: 122, protein: 8, carbs: 12, fat: 4.8),
        .init(name: "Cheese", serving: "30 g", calories: 110, protein: 7, carbs: 1, fat: 9),
        .init(name: "Oatmeal", serving: "1 cup cooked", calories: 158, protein: 6, carbs: 27, fat: 3.2),
        .init(name: "Pasta", serving: "1 cup cooked", calories: 220, protein: 8, carbs: 43, fat: 1.3),
        .init(name: "Spaghetti Bolognese", serving: "1 plate", calories: 520, protein: 22, carbs: 65, fat: 18),
        .init(name: "Pizza Slice", serving: "1 slice", calories: 285, protein: 12, carbs: 36, fat: 10),
        .init(name: "Cheeseburger", serving: "1 burger", calories: 303, protein: 15, carbs: 33, fat: 14),
        .init(name: "French Fries", serving: "medium", calories: 365, protein: 4, carbs: 48, fat: 17),
        .init(name: "Caesar Salad", serving: "1 bowl", calories: 280, protein: 9, carbs: 12, fat: 22),
        .init(name: "Green Salad", serving: "1 bowl", calories: 120, protein: 3, carbs: 10, fat: 8),
        .init(name: "Lentil Soup", serving: "1 bowl", calories: 180, protein: 12, carbs: 28, fat: 2),
        .init(name: "Hummus", serving: "2 tbsp", calories: 70, protein: 2, carbs: 6, fat: 5),
        .init(name: "Almonds", serving: "30 g", calories: 173, protein: 6, carbs: 6, fat: 15),
        .init(name: "Peanut Butter", serving: "1 tbsp", calories: 94, protein: 4, carbs: 3, fat: 8),
        .init(name: "Avocado", serving: "1/2 fruit", calories: 160, protein: 2, carbs: 9, fat: 15),
        .init(name: "Potato", serving: "1 medium", calories: 161, protein: 4, carbs: 37, fat: 0.2),
        .init(name: "Sweet Potato", serving: "1 medium", calories: 112, protein: 2, carbs: 26, fat: 0.1),
        .init(name: "Broccoli", serving: "1 cup", calories: 55, protein: 3.7, carbs: 11, fat: 0.6),
        .init(name: "Protein Shake", serving: "1 scoop", calories: 120, protein: 24, carbs: 3, fat: 1.5),
        .init(name: "Coffee with Milk", serving: "1 cup", calories: 40, protein: 2, carbs: 4, fat: 1.5),
        .init(name: "Orange Juice", serving: "1 cup", calories: 112, protein: 2, carbs: 26, fat: 0.5),
        .init(name: "Dark Chocolate", serving: "30 g", calories: 170, protein: 2, carbs: 13, fat: 12),
        .init(name: "Ice Cream", serving: "1 scoop", calories: 137, protein: 2.3, carbs: 16, fat: 7),
        .init(name: "Dates", serving: "2 pieces", calories: 110, protein: 1, carbs: 30, fat: 0),
    ]

    static func search(_ query: String) -> [CommonFood] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return foods }
        return foods.filter { $0.name.lowercased().contains(q) }
    }
}
