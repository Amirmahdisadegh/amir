import SwiftUI
import SwiftData

@main
struct CalSnapApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(appState.themeMode.colorScheme)
                .tint(Theme.Palette.brand)
        }
        .modelContainer(for: FoodEntry.self)
    }
}
