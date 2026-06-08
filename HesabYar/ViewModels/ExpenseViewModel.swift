import SwiftUI
import SwiftData
import Combine

@Observable
final class ExpenseViewModel {
    var searchText = ""
    var selectedCategory: ExpenseCategory? = nil
    var selectedDateRange: DateRange = .thisMonth
    var sortOrder: SortOrder = .dateDescending
    var showingAddExpense = false
    var showingScanner = false
    var selectedExpense: Expense? = nil

    enum DateRange: String, CaseIterable {
        case today = "امروز"
        case thisWeek = "این هفته"
        case thisMonth = "این ماه"
        case last3Months = "۳ ماه اخیر"
        case thisYear = "امسال"
        case all = "همه"
    }

    enum SortOrder: String, CaseIterable {
        case dateDescending = "جدیدترین"
        case dateAscending = "قدیمی‌ترین"
        case amountDescending = "بیشترین مبلغ"
        case amountAscending = "کمترین مبلغ"
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
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .amountDescending:
            result.sort { $0.amount > $1.amount }
        case .amountAscending:
            result.sort { $0.amount < $1.amount }
        }

        return result
    }

    // MARK: - Monthly Stats

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
        for e in monthly {
            totals[e.category, default: 0] += e.amount
        }
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
            formatter.locale = Locale(identifier: "fa_IR")
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

    // MARK: - Budget Progress

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

    // MARK: - Formatted amount

    func formatAmount(_ amount: Double, currency: String = "IRR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fa_IR")
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "\(formatted) تومان"
    }
}
