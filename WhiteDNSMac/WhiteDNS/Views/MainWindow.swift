import SwiftUI

struct MainWindow: View {
    var body: some View {
        TabView {
            ConnectionTab()
                .tabItem { Label("Connection", systemImage: "bolt.horizontal.circle") }
            ServersTab()
                .tabItem { Label("Servers", systemImage: "server.rack") }
            ResolversTab()
                .tabItem { Label("Resolvers", systemImage: "globe") }
            LogsTab()
                .tabItem { Label("Logs", systemImage: "text.alignleft") }
            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .padding()
    }
}
