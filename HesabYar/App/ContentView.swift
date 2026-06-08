import SwiftUI

struct ContentView: View {
    @AppStorage("app_language") private var appLanguage = "fa"
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("خانه", systemImage: selectedTab == 0 ? "house.fill" : "house") }
                .tag(0)

            ExpenseListView()
                .tabItem { Label("هزینه‌ها", systemImage: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle") }
                .tag(1)

            SubscriptionsView()
                .tabItem { Label("اشتراک‌ها", systemImage: "creditcard.fill") }
                .tag(2)

            ReportsView()
                .tabItem { Label("گزارش", systemImage: selectedTab == 3 ? "chart.pie.fill" : "chart.pie") }
                .tag(3)

            DebtTrackerView()
                .tabItem { Label("بدهی‌ها", systemImage: selectedTab == 4 ? "person.2.fill" : "person.2") }
                .tag(4)

            BudgetView()
                .tabItem { Label("بودجه", systemImage: selectedTab == 5 ? "chart.bar.fill" : "chart.bar") }
                .tag(5)

            AIAssistantView()
                .tabItem { Label("دستیار", systemImage: "brain") }
                .tag(6)

            SettingsView()
                .tabItem { Label("تنظیمات", systemImage: "gearshape") }
                .tag(7)
        }
        .environment(\.layoutDirection, appLanguage == "fa" || appLanguage == "ar" ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: appLanguage))
    }
}
