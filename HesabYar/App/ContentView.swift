import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(settings.t("Home", "خانه"),
                          systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            ExpenseListView()
                .tabItem {
                    Label(settings.t("Expenses", "هزینه‌ها"),
                          systemImage: selectedTab == 1 ? "creditcard.fill" : "creditcard")
                }
                .tag(1)

            SubscriptionsView()
                .tabItem {
                    Label(settings.t("Subscriptions", "اشتراک‌ها"),
                          systemImage: "arrow.clockwise.circle.fill")
                }
                .tag(2)

            AIAssistantView()
                .tabItem {
                    Label(settings.t("AI", "دستیار"),
                          systemImage: selectedTab == 3 ? "brain.head.profile" : "brain")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label(settings.t("Settings", "تنظیمات"),
                          systemImage: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                }
                .tag(4)
        }
        .tint(settings.theme.primary)
        .environment(\.layoutDirection, settings.language == "fa" ? .rightToLeft : .leftToRight)
    }
}
