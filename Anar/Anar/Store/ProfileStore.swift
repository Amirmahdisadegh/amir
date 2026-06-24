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
