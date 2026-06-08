import SwiftData
import Foundation

@Model
final class Budget {
    var id: UUID
    var categoryRaw: String
    var monthlyLimit: Double
    var currency: String
    var month: Int
    var year: Int
    var notifyAt: Double   // percentage threshold for notification (e.g. 0.8 = 80%)
    var isActive: Bool

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        category: ExpenseCategory,
        monthlyLimit: Double,
        currency: String = "IRR",
        month: Int = Calendar.current.component(.month, from: Date()),
        year: Int = Calendar.current.component(.year, from: Date()),
        notifyAt: Double = 0.8
    ) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.monthlyLimit = monthlyLimit
        self.currency = currency
        self.month = month
        self.year = year
        self.notifyAt = notifyAt
        self.isActive = true
    }
}

// MARK: - Monthly Summary

struct MonthlySummary {
    var month: Int
    var year: Int
    var totalSpent: Double
    var byCategory: [ExpenseCategory: Double]
    var expenseCount: Int
    var topCategory: ExpenseCategory?
    var dailyAverage: Double
    var comparedToPreviousMonth: Double  // percentage change

    var displayMonth: String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = month
        components.year = year
        components.day = 1
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fa_IR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Insight

struct FinancialInsight: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var icon: String
    var type: InsightType
    var amount: Double?
    var category: ExpenseCategory?

    enum InsightType {
        case warning, tip, achievement, info
    }
}
