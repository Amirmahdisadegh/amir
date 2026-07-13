import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(LocalizationManager.self) private var localization

    @State private var showConnection = false
    @State private var confirmSignOut = false
    @State private var toast: ToastData?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    connectionSection
                    securitySection
                    appearanceSection
                    aboutSection
                    signOutButton
                }
                .padding()
            }
            .background(ScreenBackground())
            .scrollContentBackground(.hidden)
            .navigationTitle("settings.title".loc)
            .sheet(isPresented: $showConnection) {
                ConnectionEditorView(toast: $toast)
            }
            .confirmationDialog("settings.logout".loc, isPresented: $confirmSignOut,
                                titleVisibility: .visible) {
                Button("settings.logout".loc, role: .destructive) {
                    Haptics.warning(); app.signOut()
                }
                Button("common.cancel".loc, role: .cancel) {}
            } message: { Text("settings.logout_confirm".loc) }
            .toast($toast)
        }
    }

    @ViewBuilder
    private var connectionSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "settings.connection".loc, symbol: "link")
                Button {
                    Haptics.tap(); showConnection = true
                } label: {
                    settingRow(icon: "server.rack", title: "settings.edit_panel".loc,
                               value: app.config.host, chevron: true)
                }
                .buttonStyle(.plain)
                Divider().overlay(Theme.cardStroke)
                Toggle(isOn: Binding(get: { app.mockMode },
                                     set: { app.mockMode = $0 })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("settings.mock_mode".loc, systemImage: "wand.and.stars")
                            .foregroundStyle(Theme.textPrimary)
                        Text("settings.mock_hint".loc)
                            .font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                }
                .tint(Theme.accentCyan)
            }
        }
    }

    private var securitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "settings.security".loc, symbol: "lock.shield")
                Toggle(isOn: Binding(get: { app.biometricLockEnabled },
                                     set: { app.biometricLockEnabled = $0 })) {
                    Label("settings.face_id".loc,
                          systemImage: BiometricAuth.kind == .touchID ? "touchid" : "faceid")
                        .foregroundStyle(Theme.textPrimary)
                }
                .tint(Theme.accentCyan)
                .disabled(!BiometricAuth.available)
                .opacity(BiometricAuth.available ? 1 : 0.4)

                Divider().overlay(Theme.cardStroke)

                Toggle(isOn: Binding(get: { app.allowInsecureTLS },
                                     set: { app.allowInsecureTLS = $0 })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("settings.allow_insecure".loc, systemImage: "exclamationmark.shield")
                            .foregroundStyle(Theme.textPrimary)
                        Text("setup.allow_insecure_hint".loc)
                            .font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                }
                .tint(Theme.warning)
            }
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        @Bindable var loc = localization
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "settings.appearance".loc, symbol: "paintbrush")
                HStack {
                    Label("settings.language".loc, systemImage: "globe")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Picker("", selection: $loc.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .tint(Theme.accentCyan)
                }
            }
        }
    }

    private var aboutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "settings.about".loc, symbol: "info.circle")
                settingRow(icon: "app.badge", title: "settings.version".loc,
                           value: appVersion, chevron: false)
                Text("settings.made_with".loc)
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var signOutButton: some View {
        Button {
            Haptics.warning(); confirmSignOut = true
        } label: {
            Label("settings.logout".loc, systemImage: "rectangle.portrait.and.arrow.right")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .foregroundStyle(Theme.expired)
                .background(Theme.expired.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func settingRow(icon: String, title: String, value: String, chevron: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.accentCyan).frame(width: 22)
            Text(title).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(Theme.textSecondary)
                .lineLimit(1).truncationMode(.middle)
            if chevron {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return Fmt.digits("\(v) (\(b))")
    }
}

#Preview {
    SettingsView()
        .environment(AppState.preview())
        .environment(LocalizationManager.shared)
        .preferredColorScheme(.dark)
}
