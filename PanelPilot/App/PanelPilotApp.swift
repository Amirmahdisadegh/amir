import SwiftUI
import SwiftData

@main
struct PanelPilotApp: App {
    let container: ModelContainer
    @State private var appState: AppState
    @State private var localization = LocalizationManager.shared

    init() {
        let schema = Schema([CachedInbound.self, CachedServerStatus.self, TrafficSample.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fall back to in-memory so the app still launches if the store is corrupt.
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
        let store = DataStore()
        store.context = ModelContext(container)
        _appState = State(initialValue: AppState(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(localization)
                .environment(\.layoutDirection, localization.layoutDirection)
                .environment(\.locale, localization.locale)
                .tint(Theme.accentCyan)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
