import SwiftUI

/// Routes between setup, biometric lock, and the main tab UI.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            ScreenBackground()
            switch app.phase {
            case .setup:
                SetupView()
                    .transition(.opacity)
            case .locked:
                LockView()
                    .transition(.opacity)
            case .ready:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(Theme.spring, value: app.phase)
        .task { await app.bootstrap() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background { app.lockIfNeeded() }
        }
    }
}

/// Biometric lock gate shown on cold launch / return from background.
struct LockView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accentGradient)
            Text("biometric.locked".loc)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button {
                Haptics.tap()
                Task { await app.unlock() }
            } label: {
                Label("biometric.unlock".loc,
                      systemImage: BiometricAuth.kind == .faceID ? "faceid" : "touchid")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(Theme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .task { await app.unlock() }
    }
}

/// Main four-tab interface.
struct MainTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("tab.dashboard".loc, systemImage: "gauge.with.dots.needle.67percent") }
                .tag(0)
            InboundsView()
                .tabItem { Label("tab.inbounds".loc, systemImage: "arrow.down.left.arrow.up.right") }
                .tag(1)
            ClientsView()
                .tabItem { Label("tab.clients".loc, systemImage: "person.2.fill") }
                .tag(2)
            SettingsView()
                .tabItem { Label("tab.settings".loc, systemImage: "gearshape.fill") }
                .tag(3)
        }
    }
}
