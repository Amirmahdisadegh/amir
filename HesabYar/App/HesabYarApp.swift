import SwiftUI
import SwiftData
import UserNotifications

@main
struct HesabYarApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([Expense.self, Debt.self, Budget.self])
            let config = ModelConfiguration("HesabYarStore", schema: schema)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData container creation failed: \(error)")
        }

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
