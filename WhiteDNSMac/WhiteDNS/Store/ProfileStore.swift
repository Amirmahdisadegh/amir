import Foundation
import SwiftUI

/// Owns all persisted state (servers, resolvers, settings, selection) and
/// writes it to a JSON file in Application Support.
@MainActor
final class ProfileStore: ObservableObject {

    @Published var data: AppData {
        didSet { scheduleSave() }
    }

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WhiteDNS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("store.json")

        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            self.data = decoded
        } else {
            self.data = AppData()
        }
        ensureDefaults()
    }

    // MARK: - Selection

    var selectedServer: ServerProfile? {
        data.servers.first { $0.id == data.selectedServerId } ?? data.servers.first
    }

    var selectedResolver: ResolverProfile {
        data.resolvers.first { $0.id == data.selectedResolverId }
            ?? data.resolvers.first
            ?? ResolverProfile.defaultResolvers
    }

    var settings: AppSettings {
        get { data.settings }
        set { data.settings = newValue }
    }

    // MARK: - Servers

    func upsertServer(_ server: ServerProfile) {
        if let i = data.servers.firstIndex(where: { $0.id == server.id }) {
            data.servers[i] = server
        } else {
            data.servers.append(server)
        }
        if data.selectedServerId == nil { data.selectedServerId = server.id }
    }

    func deleteServer(_ id: String) {
        data.servers.removeAll { $0.id == id }
        if data.selectedServerId == id { data.selectedServerId = data.servers.first?.id }
    }

    func selectServer(_ id: String) { data.selectedServerId = id }

    // MARK: - Resolvers

    func upsertResolver(_ resolver: ResolverProfile) {
        if let i = data.resolvers.firstIndex(where: { $0.id == resolver.id }) {
            data.resolvers[i] = resolver
        } else {
            data.resolvers.append(resolver)
        }
        if data.selectedResolverId == nil { data.selectedResolverId = resolver.id }
    }

    func deleteResolver(_ id: String) {
        data.resolvers.removeAll { $0.id == id }
        if data.selectedResolverId == id { data.selectedResolverId = data.resolvers.first?.id }
    }

    func selectResolver(_ id: String) { data.selectedResolverId = id }

    // MARK: - Persistence

    private func ensureDefaults() {
        if data.resolvers.isEmpty {
            data.resolvers = [ResolverProfile.defaultResolvers]
        }
        if data.selectedResolverId == nil {
            data.selectedResolverId = data.resolvers.first?.id
        }
        if data.selectedServerId == nil {
            data.selectedServerId = data.servers.first?.id
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = data
        let url = fileURL
        let work = DispatchWorkItem {
            if let encoded = try? JSONEncoder().encode(snapshot) {
                try? encoded.write(to: url, options: .atomic)
            }
        }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
