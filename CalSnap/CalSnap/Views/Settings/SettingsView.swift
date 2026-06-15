import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme

    @State private var showProfile = false
    @State private var showAPIKey = false
    @State private var showBurned = false

    var body: some View {
        @Bindable var state = appState
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("settings.title")
                    .font(Theme.Font.display(28))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .padding(.top, 8)

                goalCard

                // Appearance
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("settings.appearance")
                    themePicker(state: state)
                }
                .cardSurface()

                // Profile + Goal
                VStack(spacing: 0) {
                    settingsRow(icon: "person.fill", tint: Theme.Palette.brand,
                                title: "settings.profile",
                                subtitle: profileSubtitle) { showProfile = true }
                }
                .cardSurface(padding: 6)

                // Activity burn (manual)
                VStack(spacing: 0) {
                    settingsRow(icon: "flame.fill", tint: Theme.Palette.warning,
                                title: "settings.burned",
                                subtitle: "settings.burned.sub") {
                        showBurned = true
                    }
                }
                .cardSurface(padding: 6)

                // AI provider
                VStack(spacing: 0) {
                    settingsRow(icon: "sparkles", tint: Theme.Palette.fat,
                                title: "settings.ai",
                                subtitle: aiSubtitle) {
                        showAPIKey = true
                    }
                }
                .cardSurface(padding: 6)

                aboutCard
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, Theme.Space.md)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showProfile) { ProfileEditorView() }
        .sheet(isPresented: $showAPIKey) { AISettingsView() }
        .sheet(isPresented: $showBurned) {
            BurnedEditorView().presentationDetents([.height(280)])
        }
    }

    // MARK: Goal summary card

    private var goalCard: some View {
        let p = appState.profile
        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.dailyGoal")
                        .font(Theme.Font.caption(13))
                        .foregroundStyle(Theme.textSecondary(scheme))
                    Text("\(p.calorieGoal.grouped) kcal")
                        .font(Theme.Font.display(30))
                        .foregroundStyle(Theme.textPrimary(scheme))
                }
                Spacer()
                Image(systemName: "target")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.energyGradient)
            }
            HStack(spacing: 14) {
                goalChip("macro.protein", "\(p.proteinGoal)g", Theme.Palette.protein)
                goalChip("macro.carbs", "\(p.carbsGoal)g", Theme.Palette.carbs)
                goalChip("macro.fat", "\(p.fatGoal)g", Theme.Palette.fat)
            }
        }
        .cardSurface()
    }

    private func goalChip(_ label: LocalizedStringKey, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.Font.title(15)).foregroundStyle(tint).monospacedDigit()
            Text(label).font(Theme.Font.caption(10)).foregroundStyle(Theme.textSecondary(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private var profileSubtitle: LocalizedStringKey {
        let p = appState.profile
        return LocalizedStringKey("\(Int(p.weightKg)) kg · \(Int(p.heightCm)) cm · \(p.age)")
    }

    private var aiSubtitle: LocalizedStringKey {
        let name = appState.activeProvider.displayName
        let status = appState.hasActiveKey ? "ready" : "no API key"
        _ = appState.aiConfigVersion   // re-read when keys change
        return LocalizedStringKey("\(name) · \(status)")
    }

    // MARK: Theme picker

    private func themePicker(state: AppState) -> some View {
        HStack(spacing: 8) {
            ForEach(AppThemeMode.allCases) { mode in
                let selected = state.themeMode == mode
                Button {
                    Haptics.tap()
                    withAnimation { state.themeMode = mode }
                } label: {
                    Text(LocalizedStringKey(mode.titleKey))
                        .font(Theme.Font.caption(13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selected ? .white : Theme.textSecondary(scheme))
                        .background(
                            Capsule().fill(selected ? AnyShapeStyle(Theme.energyGradient)
                                                    : AnyShapeStyle(Theme.surfaceElevated(scheme)))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CalSnap")
                .font(Theme.Font.title(16))
                .foregroundStyle(Theme.textPrimary(scheme))
            Text("settings.about")
                .font(Theme.Font.caption(12))
                .foregroundStyle(Theme.textSecondary(scheme))
            Text("v1.0")
                .font(Theme.Font.caption(11))
                .foregroundStyle(Theme.textSecondary(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    // MARK: Rows

    private func settingsRow(icon: String, tint: Color, title: LocalizedStringKey,
                             subtitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack {
                rowLabel(icon: icon, tint: tint, title: title, subtitle: subtitle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(icon: String, tint: Color, title: LocalizedStringKey,
                          subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.Font.title(15))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Text(subtitle).font(Theme.Font.caption(11))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
        }
    }
}
