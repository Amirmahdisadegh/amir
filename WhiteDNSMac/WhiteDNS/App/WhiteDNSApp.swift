import SwiftUI
import AppKit

@main
struct WhiteDNSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var store = ProfileStore()
    @StateObject private var log: LogStore
    @StateObject private var tunnel: TunnelController

    init() {
        let log = LogStore()
        _log = StateObject(wrappedValue: log)
        _tunnel = StateObject(wrappedValue: TunnelController(log: log))
    }

    var body: some Scene {
        // Status-bar popover: the primary surface for a menu-bar app.
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(tunnel)
                .environmentObject(log)
        } label: {
            Image(systemName: tunnel.state.isConnected ? "shield.fill" : "shield")
        }
        .menuBarExtraStyle(.window)

        // Detailed management window (profiles, resolvers, logs, settings).
        Window("WhiteDNS", id: "main") {
            MainWindow()
                .environmentObject(store)
                .environmentObject(tunnel)
                .environmentObject(log)
                .frame(minWidth: 640, minHeight: 460)
                .onAppear {
                    if store.settings.autoConnectOnLaunch, let s = store.selectedServer {
                        tunnel.connect(server: s, resolver: store.selectedResolver, settings: store.settings)
                    }
                }
        }
        .windowResizability(.contentMinSize)
    }
}

/// Handles stormdns:// links opened from the browser / Finder.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme?.lowercased() == "stormdns" {
            NotificationCenter.default.post(name: .stormdnsLinkOpened, object: url.absoluteString)
        }
    }
}

extension Notification.Name {
    static let stormdnsLinkOpened = Notification.Name("stormdnsLinkOpened")
}
