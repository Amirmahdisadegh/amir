import SwiftUI

struct ContentView: View {
    @AppStorage("app_language") private var appLanguage = "fa"
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("خانه", systemImage: selectedTab == 0 ? "house.fill" : "house", value: 0) {
                DashboardView()
            }
            Tab("هزینه‌ها", systemImage: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle", value: 1) {
                ExpenseListView()
            }
            Tab("اشتراک‌ها", systemImage: "creditcard.fill", value: 2) {
                SubscriptionsView()
            }
            Tab("گزارش", systemImage: selectedTab == 3 ? "chart.pie.fill" : "chart.pie", value: 3) {
                ReportsView()
            }
            Tab("بدهی‌ها", systemImage: selectedTab == 4 ? "person.2.fill" : "person.2", value: 4) {
                DebtTrackerView()
            }
            Tab("بودجه", systemImage: selectedTab == 5 ? "chart.bar.fill" : "chart.bar", value: 5) {
                BudgetView()
            }
            Tab("دستیار", systemImage: "brain", value: 6) {
                AIAssistantView()
            }
            Tab("تنظیمات", systemImage: "gearshape", value: 7) {
                SettingsView()
            }
        }
        .environment(\.layoutDirection, appLanguage == "fa" || appLanguage == "ar" ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: appLanguage))
    }
}
