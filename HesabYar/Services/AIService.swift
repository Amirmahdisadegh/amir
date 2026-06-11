import Foundation

// MARK: - AI Provider

enum AIProvider: String, CaseIterable {
    case claude = "claude"
    case openai = "openai"
    case gemini = "gemini"

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "ChatGPT (OpenAI)"
        case .gemini: return "Gemini (Google)"
        }
    }

    var shortName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "ChatGPT"
        case .gemini: return "Gemini"
        }
    }

    var icon: String {
        switch self {
        case .claude: return "brain"
        case .openai: return "bubble.left.and.bubble.right.fill"
        case .gemini: return "sparkles"
        }
    }

    var apiKeyLabel: String {
        switch self {
        case .claude: return "Anthropic API Key"
        case .openai: return "OpenAI API Key"
        case .gemini: return "Google AI API Key"
        }
    }

    var apiKeyPrefix: String {
        switch self {
        case .claude: return "sk-ant-"
        case .openai: return "sk-"
        case .gemini: return "AI"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .claude: return "sk-ant-..."
        case .openai: return "sk-..."
        case .gemini: return "AIza..."
        }
    }
}

// MARK: - AI Service

final class AIService {
    static let shared = AIService()
    private init() {}

    // MARK: - Claude

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
            "system": "You are a smart financial assistant. Analyze the user's expense data and provide concise, actionable advice. Keep responses clear and helpful.",
            "messages": [["role": "user", "content": prompt]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = (errorJson?["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            throw AIError.apiError(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return content?["text"] as? String ?? "No response received"
    }

    // MARK: - OpenAI

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
                ["role": "system", "content": "You are a smart financial assistant. Analyze the user's expense data and provide concise, actionable advice."],
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = ((errorJson?["error"] as? [String: Any])?["message"] as? String) ?? "OpenAI error"
            throw AIError.apiError(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? "No response received"
    }

    // MARK: - Gemini

    func analyzeWithGemini(prompt: String, apiKey: String) async throws -> String {
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        let url = URL(string: urlStr)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "systemInstruction": ["parts": [["text": "You are a smart financial assistant. Analyze the user's expense data and provide concise, actionable advice."]]],
            "generationConfig": ["maxOutputTokens": 1024]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = (errorJson?["error"] as? [String: Any])?["message"] as? String ?? "Gemini error"
            throw AIError.apiError(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        return parts?.first?["text"] as? String ?? "No response received"
    }

    // MARK: - Unified Call

    func analyze(prompt: String, provider: AIProvider, apiKey: String, openAIModel: String = "gpt-4o-mini") async throws -> String {
        switch provider {
        case .claude: return try await analyzeWithClaude(prompt: prompt, apiKey: apiKey)
        case .openai: return try await analyzeWithOpenAI(prompt: prompt, apiKey: apiKey, model: openAIModel)
        case .gemini: return try await analyzeWithGemini(prompt: prompt, apiKey: apiKey)
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
                title: AppSettings.shared.t("Top Spending", "بیشترین هزینه"),
                detail: AppSettings.shared.t("\(pct)% of this month's spending was on \(topCat.key.displayName)", "این ماه \(pct)٪ هزینه برای \(topCat.key.displayName) بوده"),
                icon: topCat.key.icon, type: .info, amount: topCat.value, category: topCat.key
            ))
        }

        let recurringTotal = expenses.filter { $0.isRecurring }.reduce(0) { $0 + $1.amount }
        if recurringTotal > 0 {
            insights.append(FinancialInsight(
                title: AppSettings.shared.t("Recurring Costs", "هزینه‌های ثابت"),
                detail: AppSettings.shared.t("You have \(recurringTotal.formattedCompact) in recurring monthly expenses", "ماهانه \(recurringTotal.formattedCompact) هزینه ثابت داری"),
                icon: "arrow.clockwise.circle.fill", type: .info, amount: recurringTotal
            ))
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: now)
        let dailyAvg = dayOfMonth > 0 ? totalThisMonth / Double(dayOfMonth) : 0
        let projected = dailyAvg * Double(daysInMonth)

        if projected > totalThisMonth * 1.3 {
            insights.append(FinancialInsight(
                title: AppSettings.shared.t("Monthly Forecast", "پیش‌بینی ماهانه"),
                detail: AppSettings.shared.t("At this rate, you'll spend ~\(projected.formattedCompact) this month", "با این روند تا آخر ماه ~\(projected.formattedCompact) خرج می‌کنی"),
                icon: "chart.line.uptrend.xyaxis", type: .warning, amount: projected
            ))
        }

        let subExpenses = monthly.filter { $0.category == .subscriptions }
        if subExpenses.count > 3 {
            insights.append(FinancialInsight(
                title: AppSettings.shared.t("Many Subscriptions", "اشتراک‌های زیاد"),
                detail: AppSettings.shared.t("You have \(subExpenses.count) active subscriptions — which ones do you really need?", "\(subExpenses.count) اشتراک فعال داری — کدوم‌ها واقعاً لازمه؟"),
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
            "My financial data this month:",
            "Transactions: \(monthly.count)",
            "Total spending: \(total.formattedCompact)",
            "\nBy category:"
        ]
        for (cat, amt) in catTotals.sorted(by: { $0.value > $1.value }) {
            lines.append("• \(cat.displayName): \(amt.formattedCompact)")
        }

        if !subscriptions.isEmpty {
            let activeSubs = subscriptions.filter { $0.isActive }
            let subTotal = activeSubs.reduce(0) { $0 + $1.monthlyEquivalent }
            lines.append("\nActive subscriptions: \(activeSubs.count)")
            lines.append("Monthly subscription cost: \(subTotal.formattedCompact)")
        }

        lines.append("\nQuestion: \(question)")
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
        case .networkError: return "Network connection error"
        case .invalidKey: return "Invalid API key"
        }
    }
}
