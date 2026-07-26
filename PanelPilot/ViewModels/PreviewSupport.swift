import SwiftUI
import SwiftData

/// Convenience factories that spin up mock-backed state for SwiftUI previews.
extension AppState {
    @MainActor
    static func preview() -> AppState {
        let store = DataStore.preview()
        let state = AppState(store: store)
        state.phase = .ready
        state.mockMode = true
        return state
    }
}

extension DataStore {
    @MainActor
    static func preview() -> DataStore {
        let store = DataStore()
        let schema = Schema([CachedInbound.self, CachedServerStatus.self, TrafficSample.self])
        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]) {
            store.context = ModelContext(container)
        }
        store.inbounds = MockData.inbounds
        store.onlineEmails = Set(MockData.onlineEmails)
        store.rebuildClientRows()
        store.serverStatus = MockData.serverStatus
        store.lastUpdated = Date()
        // Seed a fake throughput curve.
        let now = Date()
        store.trafficSamples = (0..<40).map { i in
            let t = now.addingTimeInterval(Double(i - 40) * 3)
            let up = Int64(1_500_000 + 900_000 * sin(Double(i) / 4))
            let down = Int64(6_000_000 + 3_000_000 * sin(Double(i) / 3 + 1))
            return (date: t, up: up, down: down)
        }
        return store
    }
}
