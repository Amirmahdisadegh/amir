import Foundation

enum Stats {
    /// Number of consecutive days (ending today, or yesterday if today is empty)
    /// that have at least one logged meal.
    static func currentStreak(_ entries: [FoodEntry], now: Date = .now) -> Int {
        let cal = Calendar.current
        let loggedDays = Set(entries.map { cal.startOfDay(for: $0.date) })
        guard !loggedDays.isEmpty else { return 0 }

        var day = cal.startOfDay(for: now)
        if !loggedDays.contains(day) {
            // Today not logged yet — the streak can still continue from yesterday.
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day),
                  loggedDays.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while loggedDays.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}
