import Foundation
import SwiftUI

// MARK: - Goal & activity inputs used to compute a calorie target

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var titleKey: String { self == .male ? "sex.male" : "sex.female" }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, athlete
    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light:     return 1.375
        case .moderate:  return 1.55
        case .active:    return 1.725
        case .athlete:   return 1.9
        }
    }

    var titleKey: String { "activity.\(rawValue)" }
}

enum GoalDirection: String, Codable, CaseIterable, Identifiable {
    case lose, maintain, gain
    var id: String { rawValue }

    /// Daily calorie delta applied to maintenance.
    var calorieDelta: Int {
        switch self {
        case .lose:     return -500
        case .maintain: return 0
        case .gain:     return 350
        }
    }

    var titleKey: String { "goal.\(rawValue)" }
}

// MARK: - Persisted in UserDefaults via @AppStorage-friendly Codable wrapper

struct UserProfile: Codable, Equatable {
    var name: String = ""
    var sex: Sex = .male
    var age: Int = 28
    var heightCm: Double = 175
    var weightKg: Double = 72
    var activity: ActivityLevel = .moderate
    var goal: GoalDirection = .maintain

    /// If set, overrides the computed target.
    var manualCalorieGoal: Int? = nil

    /// Mifflin-St Jeor BMR.
    var bmr: Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    /// Total daily energy expenditure.
    var tdee: Double { bmr * activity.multiplier }

    /// Recommended daily calorie target.
    var calorieGoal: Int {
        if let manual = manualCalorieGoal { return manual }
        return max(1200, Int(tdee.rounded()) + goal.calorieDelta)
    }

    // Macro targets using a balanced split (30P / 40C / 30F by calories).
    var proteinGoal: Int { Int((Double(calorieGoal) * 0.30 / 4).rounded()) }
    var carbsGoal: Int   { Int((Double(calorieGoal) * 0.40 / 4).rounded()) }
    var fatGoal: Int     { Int((Double(calorieGoal) * 0.30 / 9).rounded()) }
}

// MARK: - Lightweight settings store

enum AppThemeMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var titleKey: String { "theme.\(rawValue)" }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
