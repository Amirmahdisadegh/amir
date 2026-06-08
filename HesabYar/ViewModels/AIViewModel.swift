import SwiftUI
import Observation

@Observable
final class AIViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isLoading = false
    var isOnlineMode = true
    var errorMessage: String? = nil

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "claude_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "claude_api_key") }
    }

    var hasApiKey: Bool { !apiKey.isEmpty }

    func sendMessage(expenses: [Expense]) async {
        let userText = inputText.trimmingCharacters(in: .whitespaces)
        guard !userText.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(content: userText, isUser: true))

        let loadingId = UUID()
        messages.append(ChatMessage(content: "", isUser: false, isLoading: true))
        isLoading = true
        errorMessage = nil

        do {
            let response: String

            if isOnlineMode && hasApiKey {
                let prompt = AIService.shared.buildExpenseSummaryPrompt(
                    expenses: expenses,
                    question: userText
                )
                response = try await AIService.shared.analyzeWithClaude(prompt: prompt, apiKey: apiKey)
            } else {
                response = generateOfflineResponse(question: userText, expenses: expenses)
            }

            messages.removeAll { $0.isLoading }
            messages.append(ChatMessage(content: response, isUser: false))
        } catch {
            messages.removeAll { $0.isLoading }
            let errMsg = "⚠️ خطا: \(error.localizedDescription)"
            messages.append(ChatMessage(content: errMsg, isUser: false))
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func generateOfflineResponse(question: String, expenses: [Expense]) -> String {
        let q = question.lowercased()
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let monthly = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }

        let total = monthly.reduce(0) { $0 + $1.amount }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fa_IR")

        func fmt(_ v: Double) -> String { formatter.string(from: NSNumber(value: v)) ?? "\(Int(v))" }

        if q.contains("چقدر") || q.contains("چند") || q.contains("کل") || q.contains("مجموع") {
            var catTotals: [ExpenseCategory: Double] = [:]
            for e in monthly { catTotals[e.category, default: 0] += e.amount }

            var lines = ["این ماه مجموع \(fmt(total)) تومان خرج کردی:\n"]
            for (cat, amt) in catTotals.sorted(by: { $0.value > $1.value }) {
                lines.append("• \(cat.displayName): \(fmt(amt)) تومان")
            }
            return lines.joined(separator: "\n")
        }

        if q.contains("غذا") || q.contains("رستوران") {
            let foodTotal = monthly.filter { $0.category == .food || $0.category == .restaurant || $0.category == .grocery }
                .reduce(0) { $0 + $1.amount }
            return "برای غذا و خوردنی این ماه \(fmt(foodTotal)) تومان خرج کردی."
        }

        if q.contains("اشتراک") || q.contains("ماهانه") {
            let subTotal = monthly.filter { $0.category == .subscriptions }.reduce(0) { $0 + $1.amount }
            let subs = monthly.filter { $0.category == .subscriptions }
            var lines = ["اشتراک‌های فعال این ماه (\(fmt(subTotal)) تومان):"]
            for s in subs { lines.append("• \(s.title): \(fmt(s.amount)) تومان") }
            return lines.joined(separator: "\n")
        }

        if q.contains("بیشتر") || q.contains("بالا") {
            if let top = monthly.max(by: { $0.amount < $1.amount }) {
                return "بیشترین هزینه‌ات: \(top.title) به مبلغ \(fmt(top.amount)) تومان در دسته \(top.category.displayName)"
            }
        }

        if q.contains("صرفه") || q.contains("کمتر") || q.contains("قطع") {
            let insights = AIService.shared.analyzeOffline(expenses: expenses)
            let tips = insights.filter { $0.type == .tip }.map { "• \($0.detail)" }
            return tips.isEmpty
                ? "برای صرفه‌جویی پیشنهاد خاصی ندارم - بیشتر داده نیاز است"
                : "پیشنهادهای صرفه‌جویی:\n" + tips.joined(separator: "\n")
        }

        // Default
        let insights = AIService.shared.analyzeOffline(expenses: expenses)
        if let first = insights.first {
            return "📊 \(first.title)\n\(first.detail)\n\nبرای پاسخ دقیق‌تر، کلید API را در تنظیمات وارد کن تا از هوش مصنوعی آنلاین استفاده کنم."
        }
        return "این ماه \(fmt(total)) تومان خرج کردی. برای تحلیل بیشتر سوال دقیق‌تر بپرس."
    }

    func clearChat() {
        messages.removeAll()
    }

    var suggestedQuestions: [String] {
        [
            "این ماه چقدر خرج کردم؟",
            "برای غذا چقدر هزینه داشتم؟",
            "اشتراک‌های من چیست؟",
            "چطور کمتر خرج کنم؟",
            "بیشترین هزینه‌ام کجا بود؟"
        ]
    }
}
