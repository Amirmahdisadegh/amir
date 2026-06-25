import SwiftUI
import AppKit

@main
struct AnarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var store = ProfileStore()
    @StateObject private var log: LogStore
    @StateObject private var conn: ConnectionManager

    init() {
        let log = LogStore()
        _log = StateObject(wrappedValue: log)
        _conn = StateObject(wrappedValue: ConnectionManager(log: log))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(conn)
        } label: {
            Image(systemName: conn.state.isConnected ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle")
        }
        .menuBarExtraStyle(.window)

        Window("Amir V2ray", id: "main") {
            MainWindow()
                .environmentObject(store)
                .environmentObject(conn)
                .environmentObject(log)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear {
                    if store.settings.autoConnectOnLaunch, let p = store.selected {
                        conn.connect(p, settings: store.settings)
                    }
                }
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationService.requestAuthorization()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            NotificationCenter.default.post(name: .anarLinkOpened, object: url.absoluteString)
        }
    }
}

extension Notification.Name {
    static let anarLinkOpened = Notification.Name("anarLinkOpened")
}
