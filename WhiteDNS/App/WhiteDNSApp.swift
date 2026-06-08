import SwiftUI

@main
struct WhiteDNSApp: App {
    @StateObject private var dnsManager = DNSManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dnsManager)
        }
    }
}
