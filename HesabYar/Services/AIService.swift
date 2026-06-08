import Foundation

// MARK: - AI Provider

enum AIProvider: String, CaseIterable {
    case claude = "Claude (Anthropic)"
    case openai = "OpenAI (ChatGPT)"

    var icon: String {
        switch self {
        case .claude: return "brain"
        case .openai: return "bubble.left.and.bubble.right.fill"
        }
    }

    var apiKeyLabel: String {
        switch self {
        case .claude: return "Anthropic API Key"
        case .openai: return "OpenAI API Key"
        }
    }

    var apiKeyPrefix: String {
        switch self {
        case .claude: return "sk-ant-"
        case .openai: return "sk-"
        }
    }
}

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
            پاسخ‌هایت کوتاه، واضح و کاربردی باشند.
            """,
            "messages": [["role": "user", "content": prompt]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = (errorJson?["error"] as? [String: Any])?["message"] as? String ?? "خطای ناشناخته"
            throw AIError.apiError(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return content?["text"] as? String ?? "پاسخی دریافت نشد"
    }

    // MARK: - Online: OpenAI API

    func analyzeWithOpenAI(prompt: String, apiKey: String, model: String = "gpt-4o-mini") async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                ["role": "system", "content": "تو یک دستیار مالی هوشمند هستی که به فارسی پاسخ می‌دهی. اطلاعات مالی کاربر را تحلیل کن و توصیه‌های مفید بده."],
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = ((errorJson?["error"] as? [String: Any])?["message"] as? String) ?? "خطای OpenAI"
            throw AIError.apiError(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? "پاسخی دریافت نشد"
    }

    // MARK: - Unified call

    func analyze(prompt: String, provider: AIProvider, apiKey: String, openAIModel: String = "gpt-4o-mini") async throws -> String {
        switch provider {
        case .claude:
            return try await analyzeWithClaude(prompt: prompt, apiKey: apiKey)
        case .openai:
            return try await analyzeWithOpenAI(prompt: prompt, apiKey: apiKey, model: openAIModel)
        }
    }

    // MARK: - Offline Analysis

    func analyzeOffline(expenses: [Expense]) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let monthly = expenses.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }

        let totalThisMonth = monthly.reduce(0) { $0 + $1.amount }
        var categoryTotals: [ExpenseCategory: Double] = [:]
        for expense in monthly { categoryTotals[expense.category, default: 0] += expense.amount }

        if let topCat = categoryTotals.max(by: { $0.value < $1.value }) {
            let pct = totalThisMonth > 0 ? Int((topCat.value / totalThisMonth) * 100) : 0
            insights.append(FinancialInsight(
                title: "بیشترین هزینه",
                detail: "این ماه \(pct)٪ از هزینه‌هایت برای \(topCat.key.displayName) بوده",
                icon: topCat.key.icon, type: .info, amount: topCat.value, category: topCat.key
            ))
        }

        let recurringTotal = expenses.filter { $0.isRecurring }.reduce(0) { $0 + $1.amount }
        if recurringTotal > 0 {
            insights.append(FinancialInsight(
                title: "هزینه‌های ثابت",
                detail: "ماهانه \(recurringTotal.formattedCompact) تومان هزینه ثابت داری",
                icon: "arrow.clockwise.circle.fill", type: .info, amount: recurringTotal
            ))
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: now)
        let dailyAvg = dayOfMonth > 0 ? totalThisMonth / Double(dayOfMonth) : 0
        let projected = dailyAvg * Double(daysInMonth)

        if projected > totalThisMonth * 1.3 {
            insights.append(FinancialInsight(
                title: "پیش‌بینی ماهانه",
                detail: "با این روند تا آخر ماه ~\(projected.formattedCompact) تومان خرج می‌کنی",
                icon: "chart.line.uptrend.xyaxis", type: .warning, amount: projected
            ))
        }

        let subExpenses = monthly.filter { $0.category == .subscriptions }
        if subExpenses.count > 3 {
            insights.append(FinancialInsight(
                title: "اشتراک‌های زیاد",
                detail: "\(subExpenses.count) اشتراک فعال داری — کدوم‌ها واقعاً لازمه؟",
                icon: "arrow.clockwise.circle", type: .tip
            ))
        }

        return insights
    }

    // MARK: - Prompt Builder

    func buildExpenseSummaryPrompt(expenses: [Expense], subscriptions: [SubscriptionRecord] = [], question: String) -> String {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let monthly = expenses.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }
        let total = monthly.reduce(0) { $0 + $1.amount }

        var catTotals: [ExpenseCategory: Double] = [:]
        for e in monthly { catTotals[e.category, default: 0] += e.amount }

        var lines = [
            "اطلاعات مالی این ماه:",
            "تعداد تراکنش: \(monthly.count)",
            "مجموع هزینه: \(total.formattedCompact) تومان",
            "\nبر اساس دسته‌بندی:"
        ]
        for (cat, amt) in catTotals.sorted(by: { $0.value > $1.value }) {
            lines.append("• \(cat.displayName): \(amt.formattedCompact) تومان")
        }

        if !subscriptions.isEmpty {
            let subTotal = subscriptions.filter { $0.isActive }.reduce(0) { $0 + $1.monthlyEquivalent }
            lines.append("\nاشتراک‌های فعال: \(subscriptions.filter { $0.isActive }.count)")
            lines.append("هزینه ماهانه اشتراک‌ها: \(subTotal.formattedCompact) تومان")
        }

        lines.append("\nسوال: \(question)")
        return lines.joined(separator: "\n")
    }

    func suggestCategory(for title: String, amount: Double) -> ExpenseCategory {
        OCRService.shared.guessCategory(from: title)
    }
}

// MARK: - Chat Message

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
