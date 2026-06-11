import SwiftUI
import Observation

@Observable
final class AIViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isLoading = false
    var isOnlineMode = true
    var errorMessage: String? = nil

    var provider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: "ai_provider") ?? AIProvider.claude.rawValue) ?? .claude }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "ai_provider") }
    }

    var claudeAPIKey: String {
        get { UserDefaults.standard.string(forKey: "claude_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "claude_api_key") }
    }

    var openAIKey: String {
        get { UserDefaults.standard.string(forKey: "openai_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openai_api_key") }
    }

    var geminiKey: String {
        get { UserDefaults.standard.string(forKey: "gemini_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "gemini_api_key") }
    }

    var openAIModel: String {
        get { UserDefaults.standard.string(forKey: "openai_model") ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: "openai_model") }
    }

    var activeAPIKey: String {
        switch provider {
        case .claude: return claudeAPIKey
        case .openai: return openAIKey
        case .gemini: return geminiKey
        }
    }

    var hasApiKey: Bool { !activeAPIKey.isEmpty }

    func sendMessage(expenses: [Expense], subscriptions: [SubscriptionRecord] = []) async {
        let userText = inputText.trimmingCharacters(in: .whitespaces)
        guard !userText.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(content: userText, isUser: true))
        messages.append(ChatMessage(content: "", isUser: false, isLoading: true))
        isLoading = true
        errorMessage = nil

        do {
            let response: String
            if isOnlineMode && hasApiKey {
                let prompt = AIService.shared.buildExpenseSummaryPrompt(
                    expenses: expenses, subscriptions: subscriptions, question: userText
                )
                response = try await AIService.shared.analyze(
                    prompt: prompt, provider: provider,
                    apiKey: activeAPIKey, openAIModel: openAIModel
                )
            } else {
                response = generateOfflineResponse(question: userText, expenses: expenses)
            }
            messages.removeAll { $0.isLoading }
            messages.append(ChatMessage(content: response, isUser: false))
        } catch {
            messages.removeAll { $0.isLoading }
            messages.append(ChatMessage(content: "⚠️ \(error.localizedDescription)", isUser: false))
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generateOfflineResponse(question: String, expenses: [Expense]) -> String {
        let q = question.lowercased()
        let cal = Calendar.current
        let now = Date()
        let monthly = expenses.filter {
            cal.component(.month, from: $0.date) == cal.component(.month, from: now) &&
            cal.component(.year, from: $0.date) == cal.component(.year, from: now)
        }
        let total = monthly.reduce(0) { $0 + $1.amount }

        if q.contains("total") || q.contains("spend") || q.contains("much") || q.contains("چقدر") || q.contains("مجموع") {
            var catTotals: [ExpenseCategory: Double] = [:]
            for e in monthly { catTotals[e.category, default: 0] += e.amount }
            var lines = ["This month you spent \(total.formattedCompact) total:\n"]
            for (cat, amt) in catTotals.sorted(by: { $0.value > $1.value }) {
                lines.append("• \(cat.displayName): \(amt.formattedCompact)")
            }
            return lines.joined(separator: "\n")
        }

        if q.contains("food") || q.contains("restaurant") || q.contains("grocery") || q.contains("غذا") {
            let food = monthly.filter { [.food, .restaurant, .grocery].contains($0.category) }
                .reduce(0) { $0 + $1.amount }
            return "You spent \(food.formattedCompact) on food this month."
        }

        if q.contains("subscription") || q.contains("اشتراک") {
            let subs = monthly.filter { $0.category == .subscriptions }
            let subTotal = subs.reduce(0) { $0 + $1.amount }
            var lines = ["Subscriptions this month (\(subTotal.formattedCompact)):"]
            subs.forEach { lines.append("• \($0.title): \($0.amount.formattedCompact)") }
            return lines.joined(separator: "\n")
        }

        if q.contains("most") || q.contains("highest") || q.contains("بیشتر") {
            if let top = monthly.max(by: { $0.amount < $1.amount }) {
                return "Highest expense: \(top.title) — \(top.amount.formattedCompact) (\(top.category.displayName))"
            }
        }

        let insights = AIService.shared.analyzeOffline(expenses: expenses)
        if let first = insights.first {
            return "📊 \(first.title)\n\(first.detail)\n\nFor smarter analysis, add an API key in Settings."
        }
        return "This month you spent \(total.formattedCompact). Ask me a specific question!"
    }

    func clearChat() { messages.removeAll() }

    var suggestedQuestions: [String] {
        let s = AppSettings.shared
        return [
            s.t("How much did I spend this month?", "این ماه چقدر خرج کردم؟"),
            s.t("What did I spend on food?", "برای غذا چقدر هزینه داشتم؟"),
            s.t("Show my subscriptions", "اشتراک‌های من چیست؟"),
            s.t("How can I save more?", "چطور کمتر خرج کنم؟"),
            s.t("What was my highest expense?", "بیشترین هزینه‌ام کجا بود؟")
        ]
    }
}
