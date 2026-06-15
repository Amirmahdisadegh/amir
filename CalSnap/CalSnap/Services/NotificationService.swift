import Foundation
import UserNotifications

/// Local meal reminders. Schedules three gentle daily nudges to log meals.
enum NotificationService {

    static func requestAndSchedule() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted { await schedule() }
            return granted
        } catch {
            return false
        }
    }

    static func schedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let reminders: [(id: String, hour: Int, title: String, body: String)] = [
            ("calsnap.breakfast", 9,  "Breakfast 🌅", "Snap your breakfast to start the day on track."),
            ("calsnap.lunch",     13, "Lunch ☀️",     "Time to log your lunch in CalSnap."),
            ("calsnap.dinner",    20, "Dinner 🌙",    "Don't forget to log your dinner.")
        ]

        for r in reminders {
            var date = DateComponents()
            date.hour = r.hour
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = r.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: r.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static let ids = ["calsnap.breakfast", "calsnap.lunch", "calsnap.dinner"]
}
