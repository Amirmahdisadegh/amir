import SwiftUI

struct ContentView: View {
    @StateObject private var connectVM  = ConnectVM()
    @StateObject private var profilesVM = ProfilesVM()
    @StateObject private var logsVM     = LogsVM()
    @State private var tab = 1

    var body: some View {
        TabView(selection: $tab) {
            ProfilesView()
                .tabItem { Label("پروفایل‌ها", systemImage: "list.bullet.rectangle") }
                .tag(0)

            ConnectView()
                .tabItem { Label("اتصال", systemImage: "wifi") }
                .tag(1)

            ScanView()
                .tabItem { Label("اسکن", systemImage: "scope") }
                .tag(2)

            LogsView()
                .tabItem { Label("لاگ", systemImage: "doc.text") }
                .tag(3)
        }
        .environmentObject(connectVM)
        .environmentObject(profilesVM)
        .environmentObject(logsVM)
        .preferredColorScheme(.dark)
        .onAppear { configureTabBar() }
    }

    private func configureTabBar() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Color.wdBg)

        let normal = UITabBarItemAppearance()
        normal.normal.iconColor     = UIColor(Color.wdMuted)
        normal.normal.titleTextAttributes   = [.foregroundColor: UIColor(Color.wdMuted)]
        normal.selected.iconColor   = UIColor(Color.wdAccent)
        normal.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.wdAccent)]

        a.stackedLayoutAppearance   = normal
        a.inlineLayoutAppearance    = normal
        a.compactInlineLayoutAppearance = normal

        UITabBar.appearance().standardAppearance  = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }
}
