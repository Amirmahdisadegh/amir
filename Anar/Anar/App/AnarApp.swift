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
            Image(systemName: conn.state.isConnected ? "bolt.fill" : "bolt.slash.fill")
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

    // Keep running in the menu bar after the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // Clicking the Dock icon (or reopening) brings up the main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if !flag { NotificationCenter.default.post(name: .openMainWindow, object: nil) }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            NotificationCenter.default.post(name: .anarLinkOpened, object: url.absoluteString)
        }
    }
}

extension Notification.Name {
    static let anarLinkOpened = Notification.Name("anarLinkOpened")
    static let openMainWindow = Notification.Name("openMainWindow")
}
