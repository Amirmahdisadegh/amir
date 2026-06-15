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

    /// The longest run of consecutive logged days ever.
    static func longestStreak(_ entries: [FoodEntry]) -> Int {
        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, current = 1
        for i in 1..<days.count {
            if let next = cal.date(byAdding: .day, value: 1, to: days[i - 1]),
               cal.isDate(next, inSameDayAs: days[i]) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
}
