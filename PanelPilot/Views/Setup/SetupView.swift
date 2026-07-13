import SwiftUI

/// First-run onboarding: pre-filled with the owner's panel, editable, secure.
struct SetupView: View {
    @Environment(AppState.self) private var app

    @State private var baseURL = PanelConfig.default.baseURL
    @State private var username = PanelConfig.default.username
    @State private var password = PanelConfig.default.password
    @State private var allowInsecure = false
    @State private var isConnecting = false
    @State private var error: APIError?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        field(title: "setup.base_url".loc, text: $baseURL,
                              symbol: "link", keyboard: .URL)
                        Divider().overlay(Theme.cardStroke)
                        field(title: "setup.username".loc, text: $username,
                              symbol: "person", keyboard: .default)
                        Divider().overlay(Theme.cardStroke)
                        secureField(title: "setup.password".loc, text: $password)
                    }
                }

                GlassCard {
                    Toggle(isOn: $allowInsecure) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("setup.allow_insecure".loc)
                                .foregroundStyle(Theme.textPrimary)
                            Text("setup.allow_insecure_hint".loc)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.accentCyan)
                }

                if let error {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: error.symbol)
                        Text(error.errorDescription ?? "")
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.expired)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }

                PrimaryButton(
                    title: isConnecting ? "setup.connecting".loc : "setup.connect".loc,
                    systemImage: "bolt.fill",
                    isLoading: isConnecting,
                    isEnabled: !baseURL.isEmpty && !username.isEmpty
                ) { connect() }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 46))
                .foregroundStyle(Theme.accentGradient)
            Text("setup.title".loc)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("setup.subtitle".loc)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 40)
    }

    private func field(title: String, text: Binding<String>, symbol: String,
                       keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            TextField("", text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func secureField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "lock")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            SecureField("", text: text)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func connect() {
        error = nil
        isConnecting = true
        app.allowInsecureTLS = allowInsecure
        let config = PanelConfig(baseURL: baseURL, username: username, password: password)
        Task {
            do {
                try await app.connect(with: config)
                Haptics.success()
            } catch {
                self.error = APIError.from(error)
                Haptics.error()
            }
            isConnecting = false
        }
    }
}

#Preview {
    SetupView()
        .environment(AppState.preview())
        .preferredColorScheme(.dark)
}
