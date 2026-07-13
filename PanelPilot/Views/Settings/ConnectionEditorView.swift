import SwiftUI

/// Edit the panel connection from Settings and re-authenticate.
struct ConnectionEditorView: View {
    @Binding var toast: ToastData?
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isSaving = false
    @State private var error: APIError?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            field("setup.base_url".loc, symbol: "link", text: $baseURL, keyboard: .URL)
                            Divider().overlay(Theme.cardStroke)
                            field("setup.username".loc, symbol: "person", text: $username, keyboard: .default)
                            Divider().overlay(Theme.cardStroke)
                            secure("setup.password".loc, text: $password)
                        }
                    }
                    if let error {
                        Label(error.errorDescription ?? "", systemImage: error.symbol)
                            .font(.subheadline).foregroundStyle(Theme.expired)
                    }
                    PrimaryButton(title: "settings.reconnect".loc, systemImage: "bolt.fill",
                                  isLoading: isSaving,
                                  isEnabled: !baseURL.isEmpty && !username.isEmpty) { save() }
                }
                .padding()
            }
            .background(ScreenBackground())
            .scrollContentBackground(.hidden)
            .navigationTitle("settings.edit_panel".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".loc) { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .onAppear {
                baseURL = app.config.baseURL.isEmpty ? PanelConfig.default.baseURL : app.config.baseURL
                username = app.config.username.isEmpty ? PanelConfig.default.username : app.config.username
                // Fall back to the default password if a prior failed attempt left it blank,
                // so the user never has to retype it just to reconnect.
                password = app.config.password.isEmpty ? PanelConfig.default.password : app.config.password
            }
        }
        .preferredColorScheme(.dark)
    }

    private func field(_ title: String, symbol: String, text: Binding<String>,
                       keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
            TextField("", text: text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(keyboard).foregroundStyle(Theme.textPrimary)
        }
    }

    private func secure(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "lock")
                .font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
            SecureField("", text: text).foregroundStyle(Theme.textPrimary)
        }
    }

    private func save() {
        error = nil
        isSaving = true
        let config = PanelConfig(baseURL: baseURL, username: username, password: password)
        Task {
            do {
                try await app.updateConnection(config)
                toast = ToastData(message: "settings.connection_ok".loc)
                Haptics.success()
                dismiss()
            } catch {
                self.error = APIError.from(error)
                Haptics.error()
            }
            isSaving = false
        }
    }
}
