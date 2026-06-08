import SwiftUI
import SwiftData
import UserNotifications

@main
struct HesabYarApp: App {
    let container: ModelContainer
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        do {
            let schema = Schema([Expense.self, Debt.self, Budget.self, SubscriptionRecord.self])
            let config = ModelConfiguration("HesabYarStore", schema: schema)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData container creation failed: \(error)")
        }

        Task {
            await NotificationService.shared.requestPermission()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}

// MARK: - App Delegate for Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  willPresent notification: UNNotification,
                                  withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  didReceive response: UNNotificationResponse,
                                  withCompletionHandler handler: @escaping () -> Void) {
        handler()
    }
}
