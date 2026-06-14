import SwiftUI

struct APIKeyView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var key: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.energyGradient)
                        Text("apikey.heading")
                            .font(Theme.Font.title(20))
                            .foregroundStyle(Theme.textPrimary(scheme))
                        Text("apikey.body")
                            .font(Theme.Font.body(14))
                            .foregroundStyle(Theme.textSecondary(scheme))
                    }

                    SecureField("apikey.placeholder", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .cardSurface(padding: 14, radius: Theme.Radius.md)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("apikey.step1", systemImage: "1.circle.fill")
                        Label("apikey.step2", systemImage: "2.circle.fill")
                        Label("apikey.step3", systemImage: "3.circle.fill")
                    }
                    .font(Theme.Font.caption(13))
                    .foregroundStyle(Theme.textSecondary(scheme))

                    Label("apikey.privacy", systemImage: "lock.fill")
                        .font(Theme.Font.caption(12))
                        .foregroundStyle(Theme.Palette.brand)

                    Button("action.save") { save() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)

                    if appState.hasAPIKey {
                        Button("apikey.remove") { remove() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(Theme.Space.md)
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("settings.apiKey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
            }
            .onAppear { key = appState.apiKey ?? "" }
        }
    }

    private func save() {
        appState.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        Haptics.success()
        dismiss()
    }

    private func remove() {
        appState.apiKey = nil
        key = ""
        dismiss()
    }
}
