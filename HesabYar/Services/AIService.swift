import Foundation

// MARK: - AI Service (Online + Offline)

final class AIService {
    static let shared = AIService()
    private init() {}

    // MARK: - Online: Claude API

    func analyzeWithClaude(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "system": """
            تو یک دستیار مالی هوشمند هستی که به فارسی کمک می‌کنی.
            اطلاعات هزینه‌های کاربر را تحلیل کن و توصیه‌های مفید بده.
            پاسخ‌هایت باید کوتاه، واضح و کاربردی باشند.
            از اعداد دقیق استفاده کن و واحد پول را ذکر کن.
            """,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.apiError("خطا در اتصال به سرور")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return content?["text"] as? String ?? "پاسخی دریافت نشد"
    }

    // MARK: - Offline: Local Analysis

    func analyzeOffline(expenses: [Expense]) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []

        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let monthlyExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }

        let totalThisMonth = monthlyExpenses.reduce(0) { $0 + $1.amount }

        // Category breakdown
        var categoryTotals: [ExpenseCategory: Double] = [:]
        for expense in monthlyExpenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }

        // Top spending category
        if let topCat = categoryTotals.max(by: { $0.value < $1.value }) {
            let percentage = totalThisMonth > 0 ? Int((topCat.value / totalThisMonth) * 100) : 0
            insights.append(FinancialInsight(
                title: "بیشترین هزینه",
                detail: "این ماه \(percentage)% از بودجه‌ات رو برای \(topCat.key.displayName) خرج کردی",
                icon: topCat.key.icon,
                type: .info,
                amount: topCat.value,
                category: topCat.key
            ))
        }

        // Recurring expense detection
        let recurringExpenses = expenses.filter { $0.isRecurring }
        if !recurringExpenses.isEmpty {
            let recurringTotal = recurringExpenses.reduce(0) { $0 + $1.amount }
            insights.append(FinancialInsight(
                title: "هزینه‌های ثابت",
                detail: "ماهانه \(formatAmount(recurringTotal)) تومان هزینه اشتراک و ثابت داری",
                icon: "arrow.clockwise.circle.fill",
                type: .info,
                amount: recurringTotal
            ))
        }

        // Daily average
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: now)
        let dailyAvg = dayOfMonth > 0 ? totalThisMonth / Double(dayOfMonth) : 0
        let projectedMonthly = dailyAvg * Double(daysInMonth)

        if projectedMonthly > totalThisMonth * 1.3 {
            insights.append(FinancialInsight(
                title: "پیش‌بینی ماهانه",
                detail: "با این روند، تا آخر ماه حدود \(formatAmount(projectedMonthly)) تومان خرج می‌کنی",
                icon: "chart.line.uptrend.xyaxis",
                type: .warning,
                amount: projectedMonthly
            ))
        }

        // Subscription detection
        let subscriptionTotal = categoryTotals[.subscriptions, default: 0]
        if subscriptionTotal > 0 {
            let subExpenses = monthlyExpenses.filter { $0.category == .subscriptions }
            if subExpenses.count > 3 {
                insights.append(FinancialInsight(
                    title: "اشتراک‌های زیاد",
                    detail: "\(subExpenses.count) اشتراک فعال داری - بررسی کن کدوم‌ها لازم هستن",
                    icon: "arrow.clockwise.circle",
                    type: .tip
                ))
            }
        }

        // Weekend vs weekday spending
        let weekendExpenses = monthlyExpenses.filter {
            let weekday = calendar.component(.weekday, from: $0.date)
            return weekday == 1 || weekday == 7  // Sunday or Saturday
        }
        let weekendTotal = weekendExpenses.reduce(0) { $0 + $1.amount }
        let weekendRatio = totalThisMonth > 0 ? weekendTotal / totalThisMonth : 0
        if weekendRatio > 0.4 {
            insights.append(FinancialInsight(
                title: "خرج آخر هفته",
                detail: "\(Int(weekendRatio * 100))% از هزینه‌هایت آخر هفته‌اس - سعی کن برنامه‌ریزی کنی",
                icon: "calendar.badge.exclamationmark",
                type: .tip
            ))
        }

        return insights
    }

    // MARK: - Expense Summary Generator (for chat context)

    func buildExpenseSummaryPrompt(expenses: [Expense], question: String) -> String {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let monthlyExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }

        var categoryTotals: [ExpenseCategory: Double] = [:]
        for expense in monthlyExpenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }

        let totalSpent = monthlyExpenses.reduce(0) { $0 + $1.amount }
        let expenseCount = monthlyExpenses.count

        var summaryLines = [
            "خلاصه هزینه‌های این ماه:",
            "تعداد تراکنش: \(expenseCount)",
            "مجموع: \(formatAmount(totalSpent)) تومان",
            "",
            "بر اساس دسته‌بندی:"
        ]

        for (cat, amount) in categoryTotals.sorted(by: { $0.value > $1.value }) {
            summaryLines.append("- \(cat.displayName): \(formatAmount(amount)) تومان")
        }

        let recentTransactions = expenses.sorted { $0.date > $1.date }.prefix(10)
        summaryLines.append("")
        summaryLines.append("آخرین تراکنش‌ها:")
        for expense in recentTransactions {
            summaryLines.append("- \(expense.title): \(formatAmount(expense.amount)) تومان (\(expense.category.displayName))")
        }

        summaryLines.append("")
        summaryLines.append("سوال کاربر: \(question)")

        return summaryLines.joined(separator: "\n")
    }

    // MARK: - Category Suggestion

    func suggestCategory(for title: String, amount: Double) -> ExpenseCategory {
        OCRService.shared.guessCategory(from: title)
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fa_IR")
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }
}

// MARK: - AI Chat Message

struct ChatMessage: Identifiable {
    var id = UUID()
    var content: String
    var isUser: Bool
    var timestamp: Date = Date()
    var isLoading: Bool = false
}

// MARK: - Errors

enum AIError: LocalizedError {
    case apiError(String)
    case networkError
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return msg
        case .networkError: return "خطا در اتصال به اینترنت"
        case .invalidKey: return "کلید API نامعتبر است"
        }
    }
}
