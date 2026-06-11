import SwiftUI
import SwiftData
import Observation

@Observable
final class ExpenseViewModel {
    var searchText = ""
    var selectedCategory: ExpenseCategory? = nil
    var selectedDateRange: DateRange = .thisMonth
    var sortOrder: SortOrder = .dateDescending

    enum DateRange: String, CaseIterable {
        case today       = "Today"
        case thisWeek    = "This Week"
        case thisMonth   = "This Month"
        case last3Months = "3 Months"
        case thisYear    = "This Year"
        case all         = "All Time"

        var displayName: String {
            AppSettings.shared.t(rawValue, {
                switch self {
                case .today:       return "امروز"
                case .thisWeek:    return "این هفته"
                case .thisMonth:   return "این ماه"
                case .last3Months: return "۳ ماه اخیر"
                case .thisYear:    return "امسال"
                case .all:         return "همه"
                }
            }())
        }
    }

    enum SortOrder: String, CaseIterable {
        case dateDescending  = "Newest First"
        case dateAscending   = "Oldest First"
        case amountDescending = "Highest Amount"
        case amountAscending  = "Lowest Amount"

        var displayName: String {
            AppSettings.shared.t(rawValue, {
                switch self {
                case .dateDescending:   return "جدیدترین"
                case .dateAscending:    return "قدیمی‌ترین"
                case .amountDescending: return "بیشترین مبلغ"
                case .amountAscending:  return "کمترین مبلغ"
                }
            }())
        }
    }

    func filteredExpenses(_ expenses: [Expense]) -> [Expense] {
        var result = expenses

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.merchant.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        let now = Date()
        let calendar = Calendar.current
        switch selectedDateRange {
        case .today:
            result = result.filter { calendar.isDateInToday($0.date) }
        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            result = result.filter { $0.date >= start }
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: comps)!
            result = result.filter { $0.date >= start }
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -3, to: now)!
            result = result.filter { $0.date >= start }
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: now)
            let start = calendar.date(from: comps)!
            result = result.filter { $0.date >= start }
        case .all:
            break
        }

        switch sortOrder {
        case .dateDescending:   result.sort { $0.date > $1.date }
        case .dateAscending:    result.sort { $0.date < $1.date }
        case .amountDescending: result.sort { $0.amount > $1.amount }
        case .amountAscending:  result.sort { $0.amount < $1.amount }
        }

        return result
    }

    func monthlyTotal(_ expenses: [Expense]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        return expenses
            .filter {
                calendar.component(.month, from: $0.date) == calendar.component(.month, from: now) &&
                calendar.component(.year, from: $0.date) == calendar.component(.year, from: now)
            }
            .reduce(0) { $0 + $1.amount }
    }

    func categoryBreakdown(_ expenses: [Expense]) -> [(ExpenseCategory, Double)] {
        let calendar = Calendar.current
        let now = Date()
        let monthly = expenses.filter {
            calendar.component(.month, from: $0.date) == calendar.component(.month, from: now) &&
            calendar.component(.year, from: $0.date) == calendar.component(.year, from: now)
        }
        var totals: [ExpenseCategory: Double] = [:]
        for e in monthly { totals[e.category, default: 0] += e.amount }
        return totals.sorted { $0.value > $1.value }
    }

    func last6MonthsData(_ expenses: [Expense]) -> [(month: String, total: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(String, Double)] = []

        for offset in (0..<6).reversed() {
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)

            let total = expenses
                .filter {
                    calendar.component(.month, from: $0.date) == month &&
                    calendar.component(.year, from: $0.date) == year
                }
                .reduce(0) { $0 + $1.amount }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMM"
            result.append((formatter.string(from: date), total))
        }
        return result
    }

    func dailySpending(_ expenses: [Expense]) -> [(day: Int, total: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30

        let monthly = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }

        var byDay: [Int: Double] = [:]
        for expense in monthly {
            let day = calendar.component(.day, from: expense.date)
            byDay[day, default: 0] += expense.amount
        }

        return (1...daysInMonth).map { day in (day, byDay[day] ?? 0) }
    }

    func budgetProgress(for category: ExpenseCategory, budgets: [Budget], expenses: [Expense]) -> Double? {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        guard let budget = budgets.first(where: {
            $0.category == category &&
            $0.month == currentMonth &&
            $0.year == currentYear &&
            $0.isActive
        }) else { return nil }

        let spent = expenses
            .filter {
                $0.category == category &&
                calendar.component(.month, from: $0.date) == currentMonth &&
                calendar.component(.year, from: $0.date) == currentYear
            }
            .reduce(0) { $0 + $1.amount }

        return budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : nil
    }
}
