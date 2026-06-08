import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        return granted ?? false
    }

    // MARK: - Subscription Reminders

    func scheduleSubscriptionReminder(for sub: SubscriptionRecord) {
        cancelNotification(id: "sub_\(sub.id)")
        guard sub.isActive, sub.notifyBeforeDays > 0 else { return }

        let notifyDate = Calendar.current.date(
            byAdding: .day, value: -sub.notifyBeforeDays, to: sub.nextRenewalDate
        ) ?? sub.nextRenewalDate

        guard notifyDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "تمدید اشتراک 📅"
        content.body = "\(sub.displayName) \(sub.notifyBeforeDays) روز دیگه تمدید میشه — \(sub.amount.formattedAsCurrency)"
        content.sound = .default
        content.badge = 1
        content.userInfo = ["subscriptionId": sub.id.uuidString]

        var components = Calendar.current.dateComponents([.year, .month, .day], from: notifyDate)
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "sub_\(sub.id)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleAllSubscriptionReminders(_ subs: [SubscriptionRecord]) {
        subs.forEach { scheduleSubscriptionReminder(for: $0) }
    }

    // MARK: - Budget Alerts

    func sendBudgetAlert(category: ExpenseCategory, spent: Double, limit: Double) {
        let pct = Int((spent / limit) * 100)
        let content = UNMutableNotificationContent()

        if spent >= limit {
            content.title = "⚠️ بودجه تمام شد"
            content.body = "بودجه \(category.displayName) تمام شد! \(spent.formattedAsCurrency) از \(limit.formattedAsCurrency) خرج شده."
        } else {
            content.title = "هشدار بودجه 💰"
            content.body = "\(pct)٪ بودجه \(category.displayName) مصرف شده — \(spent.formattedAsCurrency) از \(limit.formattedAsCurrency)"
        }

        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "budget_\(category.rawValue)_\(Date().timeIntervalSince1970)",
            content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Weekly Summary

    func scheduleWeeklySummary() {
        cancelNotification(id: "weekly_summary")
        let content = UNMutableNotificationContent()
        content.title = "خلاصه هفتگی 📊"
        content.body = "ببین این هفته چقدر خرج کردی — حسابیار آماده‌ست!"
        content.sound = .default

        var components = DateComponents()
        components.weekday = 2  // Monday
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_summary", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Debt Reminder

    func scheduleDebtReminder(for debt: Debt) {
        cancelNotification(id: "debt_\(debt.id)")
        guard !debt.isPaid, let dueDate = debt.dueDate, dueDate > Date() else { return }

        let notifyDate = Calendar.current.date(byAdding: .day, value: -2, to: dueDate) ?? dueDate
        guard notifyDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = debt.isOwedToMe ? "یادآوری دریافت 💸" : "یادآوری پرداخت 💸"
        content.body = "\(debt.personName): \(debt.amount.formattedAsCurrency) — سررسید ۲ روز دیگه"
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: notifyDate)
        components.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "debt_\(debt.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAllSubscriptionNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("sub_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }
}
