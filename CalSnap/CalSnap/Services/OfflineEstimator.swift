import Foundation

/// A deliberately simple fallback used when no Claude API key is configured.
/// It cannot see the photo, so it returns a neutral "typical meal" estimate that
/// the user is expected to adjust. Keeps the app fully functional offline.
enum OfflineEstimator {

    /// Very rough keyword table to nudge the estimate when the user typed a hint.
    private static let keywords: [(words: [String], cals: Int, p: Double, c: Double, f: Double)] = [
        (["salad", "سالاد", "کاهو"], 220, 8, 18, 12),
        (["chicken", "مرغ", "kebab", "کباب"], 480, 42, 12, 26),
        (["rice", "برنج", "polo", "پلو", "چلو"], 380, 7, 78, 4),
        (["pasta", "پاستا", "ماکارونی", "spaghetti"], 520, 18, 74, 16),
        (["burger", "برگر", "همبرگر"], 650, 30, 45, 38),
        (["pizza", "پیتزا"], 700, 28, 70, 32),
        (["soup", "سوپ", "آش"], 200, 9, 24, 7),
        (["fruit", "میوه", "apple", "سیب", "banana", "موز"], 110, 1, 27, 0),
        (["egg", "تخم مرغ", "omelet", "املت"], 260, 18, 4, 19),
        (["bread", "نان", "sandwich", "ساندویچ"], 350, 14, 44, 12),
    ]

    static func estimate(hint: String?) -> FoodAnalysis {
        let lower = (hint ?? "").lowercased()
        let match = keywords.first { entry in
            entry.words.contains { lower.contains($0) }
        }

        let name = (hint?.isEmpty == false ? hint! : "Estimated meal")
        let m = match ?? (words: [], cals: 450, p: 20, c: 45, f: 18)

        let item = FoodItem(
            name: name,
            quantity: "1 serving",
            calories: m.cals,
            proteinGrams: m.p,
            carbsGrams: m.c,
            fatGrams: m.f,
            confidence: 0.35
        )
        return FoodAnalysis(
            title: name,
            items: [item],
            summary: "Offline estimate — add your Claude API key for accurate AI recognition.",
            isEstimateOnly: true
        )
    }
}
