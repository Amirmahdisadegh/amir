import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("خانه", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            ExpenseListView()
                .tabItem {
                    Label("هزینه‌ها", systemImage: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                }
                .tag(1)

            ReportsView()
                .tabItem {
                    Label("گزارش", systemImage: selectedTab == 2 ? "chart.pie.fill" : "chart.pie")
                }
                .tag(2)

            DebtTrackerView()
                .tabItem {
                    Label("بدهی‌ها", systemImage: selectedTab == 3 ? "person.2.fill" : "person.2")
                }
                .tag(3)

            BudgetView()
                .tabItem {
                    Label("بودجه", systemImage: selectedTab == 4 ? "chart.bar.fill" : "chart.bar")
                }
                .tag(4)

            AIAssistantView()
                .tabItem {
                    Label("دستیار", systemImage: selectedTab == 5 ? "brain.head.profile" : "brain")
                }
                .tag(5)

            SettingsView()
                .tabItem {
                    Label("تنظیمات", systemImage: "gearshape")
                }
                .tag(6)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
