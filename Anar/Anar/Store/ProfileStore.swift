import Foundation
import SwiftUI

@MainActor
final class ProfileStore: ObservableObject {

    @Published var data: AnarData { didSet { scheduleSave() } }

    private let fileURL: URL
    private var saveItem: DispatchWorkItem?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Anar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("store.json")

        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AnarData.self, from: raw) {
            data = decoded
        } else {
            data = AnarData()
        }
        if data.selectedId == nil { data.selectedId = data.profiles.first?.id }
        // Migrate older stores to the no-password TUN mode.
        if data.schemaVersion < 1 {
            data.settings.mode = .tun
            data.schemaVersion = 1
        }
    }

    var selected: ProxyProfile? {
        data.profiles.first { $0.id == data.selectedId } ?? data.profiles.first
    }

    var settings: AppSettings {
        get { data.settings }
        set { data.settings = newValue }
    }

    func select(_ id: String) { data.selectedId = id }

    func upsert(_ profile: ProxyProfile) {
        if let i = data.profiles.firstIndex(where: { $0.id == profile.id }) {
            data.profiles[i] = profile
        } else {
            data.profiles.append(profile)
        }
        if data.selectedId == nil { data.selectedId = profile.id }
    }

    func add(_ profiles: [ProxyProfile]) {
        data.profiles.append(contentsOf: profiles)
        if data.selectedId == nil { data.selectedId = data.profiles.first?.id }
    }

    func delete(_ id: String) {
        data.profiles.removeAll { $0.id == id }
        if data.selectedId == id { data.selectedId = data.profiles.first?.id }
    }

    func setLatency(_ id: String, _ ms: Int?) {
        guard let i = data.profiles.firstIndex(where: { $0.id == id }) else { return }
        data.profiles[i].latencyMs = ms
    }

    // MARK: - Subscriptions

    func addSubscription(_ sub: Subscription) {
        data.subscriptions.append(sub)
    }

    func deleteSubscription(_ id: String) {
        data.subscriptions.removeAll { $0.id == id }
        data.profiles.removeAll { $0.subscriptionId == id }
    }

    /// Fetches a subscription URL and replaces that subscription's servers.
    func refreshSubscription(_ id: String) async {
        guard let i = data.subscriptions.firstIndex(where: { $0.id == id }),
              let url = URL(string: data.subscriptions[i].url) else { return }
        guard let (raw, _) = try? await URLSession.shared.data(from: url),
              let body = String(data: raw, encoding: .utf8) else { return }
        var parsed = LinkParser.parseMany(body)
        for k in parsed.indices { parsed[k].subscriptionId = id }
        guard !parsed.isEmpty else { return }
        data.profiles.removeAll { $0.subscriptionId == id }
        data.profiles.append(contentsOf: parsed)
        data.subscriptions[i].lastUpdated = Date()
        if data.selectedId == nil { data.selectedId = data.profiles.first?.id }
    }

    /// TCP-pings every server concurrently and stores the results.
    func testAllLatencies() async {
        await withTaskGroup(of: (String, Int?).self) { group in
            for p in data.profiles {
                group.addTask { (p.id, await LatencyTester.ping(host: p.server, port: p.port)) }
            }
            for await (id, ms) in group { setLatency(id, ms) }
        }
    }

    private func scheduleSave() {
        saveItem?.cancel()
        let snapshot = data
        let url = fileURL
        let item = DispatchWorkItem {
            if let encoded = try? JSONEncoder().encode(snapshot) {
                try? encoded.write(to: url, options: .atomic)
            }
        }
        saveItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3, execute: item)
    }
}
