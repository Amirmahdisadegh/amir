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

    var openAIModel: String {
        get { UserDefaults.standard.string(forKey: "openai_model") ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: "openai_model") }
    }

    var activeAPIKey: String {
        switch provider {
        case .claude: return claudeAPIKey
        case .openai: return openAIKey
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

        if q.contains("چقدر") || q.contains("مجموع") || q.contains("کل") {
            var catTotals: [ExpenseCategory: Double] = [:]
            for e in monthly { catTotals[e.category, default: 0] += e.amount }
            var lines = ["این ماه مجموع \(total.formattedCompact) تومان خرج کردی:\n"]
            for (cat, amt) in catTotals.sorted(by: { $0.value > $1.value }) {
                lines.append("• \(cat.displayName): \(amt.formattedCompact) تومان")
            }
            return lines.joined(separator: "\n")
        }

        if q.contains("غذا") || q.contains("رستوران") {
            let food = monthly.filter { [.food, .restaurant, .grocery].contains($0.category) }
                .reduce(0) { $0 + $1.amount }
            return "برای غذا این ماه \(food.formattedCompact) تومان خرج کردی."
        }

        if q.contains("اشتراک") {
            let subs = monthly.filter { $0.category == .subscriptions }
            let subTotal = subs.reduce(0) { $0 + $1.amount }
            var lines = ["اشتراک‌های این ماه (\(subTotal.formattedCompact) تومان):"]
            subs.forEach { lines.append("• \($0.title): \($0.amount.formattedCompact) تومان") }
            return lines.joined(separator: "\n")
        }

        if q.contains("بیشتر") || q.contains("بالا") {
            if let top = monthly.max(by: { $0.amount < $1.amount }) {
                return "بیشترین هزینه: \(top.title) — \(top.amount.formattedCompact) تومان (\(top.category.displayName))"
            }
        }

        let insights = AIService.shared.analyzeOffline(expenses: expenses)
        if let first = insights.first {
            return "📊 \(first.title)\n\(first.detail)\n\nبرای تحلیل دقیق‌تر، در تنظیمات API Key وارد کن."
        }
        return "این ماه \(total.formattedCompact) تومان خرج کردی. سوال دقیق‌تری بپرس."
    }

    func clearChat() { messages.removeAll() }

    var suggestedQuestions: [String] {
        ["این ماه چقدر خرج کردم؟", "برای غذا چقدر هزینه داشتم؟",
         "اشتراک‌های من چیست؟", "چطور کمتر خرج کنم؟", "بیشترین هزینه‌ام کجا بود؟"]
    }
}
