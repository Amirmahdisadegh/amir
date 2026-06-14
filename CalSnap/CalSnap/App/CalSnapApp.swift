import SwiftUI
import SwiftData

@main
struct CalSnapApp: App {
    @State private var appState = AppState()
    private let container: ModelContainer = CalSnapApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(appState.themeMode.colorScheme)
                .tint(Theme.Palette.brand)
        }
        .modelContainer(container)
    }

    /// Builds the SwiftData container resiliently. If an existing on-disk store
    /// is incompatible with the current schema (e.g. after a model change), the
    /// stale store is deleted and recreated instead of crashing at launch.
    /// Falls back to an in-memory store as a last resort so the app always opens.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([FoodEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // Remove a stale/incompatible store, then try once more.
        let support = URL.applicationSupportDirectory
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? FileManager.default.removeItem(at: support.appending(path: name))
        }
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memory])
    }
}
