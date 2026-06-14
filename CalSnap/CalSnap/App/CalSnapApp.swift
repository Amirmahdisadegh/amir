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

    /// Builds the SwiftData container resiliently: if the on-disk store is
    /// incompatible (e.g. the schema changed between versions), the old store is
    /// removed and recreated instead of crashing at launch. Falls back to an
    /// in-memory store as a last resort so the app always opens.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([FoodEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // Wipe a stale/incompatible store and try once more.
        let support = URL.applicationSupportDirectory
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? FileManager.default.removeItem(at: support.appending(path: name))
        }
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // Last resort: in-memory (data won't persist, but the app launches).
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memory])
    }
}
