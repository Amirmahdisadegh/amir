import SwiftUI

/// Shows onboarding until completed, then the main tabbed experience.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        // Applied here (inside a View) so it reacts to theme changes live.
        .preferredColorScheme(appState.themeMode.colorScheme)
        // Rebuild the tree when accent / background / glass change so the
        // statically-read Theme values refresh everywhere.
        .id(appState.appearanceVersion)
    }
}

// MARK: - Tab bar

enum AppTab: Int, CaseIterable {
    case home, diary, capture, insights, settings
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var showCapture = false

    var body: some View {
        @Bindable var state = appState
        return ZStack(alignment: .bottom) {
            AuroraBackground()

            Group {
                switch appState.selectedTab {
                case .home:     HomeView()
                case .diary:    DiaryView()
                case .capture:  HomeView() // placeholder; capture is modal
                case .insights: InsightsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selection: $state.selectedTab) {
                Haptics.tap()
                showCapture = true
            }
        }
        .fullScreenCover(isPresented: $showCapture) {
            CaptureFlowView()
        }
    }
}

// MARK: - Custom floating tab bar with a center capture button

struct CustomTabBar: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: AppTab
    var onCapture: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, icon: "house.fill", label: "tab.home")
            tabButton(.diary, icon: "book.fill", label: "tab.diary")

            // Center capture button
            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .fill(Theme.energyGradient)
                        .frame(width: 60, height: 60)
                        .shadow(color: Theme.Palette.brand.opacity(0.5), radius: 12, y: 6)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: -14)
            }
            .frame(maxWidth: .infinity)

            tabButton(.insights, icon: "chart.bar.fill", label: "tab.insights")
            tabButton(.settings, icon: "gearshape.fill", label: "tab.settings")
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.surface(scheme).opacity(scheme == .dark ? 0.85 : 0.92))
                .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 14, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.glassBorder(scheme), lineWidth: 1)
        )
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, 6)
    }

    private func tabButton(_ tab: AppTab, icon: String, label: LocalizedStringKey) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(selection == tab
                             ? Theme.Palette.brand
                             : Theme.textSecondary(scheme))
            .frame(maxWidth: .infinity)
        }
    }
}
