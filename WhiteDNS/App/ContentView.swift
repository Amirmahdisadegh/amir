import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("خانه", systemImage: "house.fill")
                }

            ProvidersView()
                .tabItem {
                    Label("سرورها", systemImage: "server.rack")
                }

            SettingsView()
                .tabItem {
                    Label("تنظیمات", systemImage: "gearshape.fill")
                }
        }
    }
}
