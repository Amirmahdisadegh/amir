import SwiftUI

/// Choose the AI provider (Claude / ChatGPT / Gemini), enter its API key and
/// pick the model. The selected provider is the one used for recognition.
struct AISettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var selected: AIProvider = .claude
    @State private var key: String = ""
    @State private var model: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    providerPicker
                    keyCard
                    modelCard
                    Color.clear.frame(height: 20)
                }
                .padding(Theme.Space.md)
            }
            .background(AuroraBackground())
            .navigationTitle("ai.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") {
                        saveCurrent()
                        appState.activeProvider = selected
                        Haptics.success()
                        dismiss()
                    }.bold()
                }
            }
            .onAppear {
                selected = appState.activeProvider
                loadProvider(selected)
            }
        }
    }

    // MARK: Provider picker

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ai.choose")
                .font(Theme.Font.caption(13))
                .foregroundStyle(Theme.textSecondary(scheme))
            HStack(spacing: 8) {
                ForEach(AIProvider.allCases) { provider in
                    providerChip(provider)
                }
            }
        }
    }

    private func providerChip(_ provider: AIProvider) -> some View {
        let isSelected = selected == provider
        let configured = appState.hasKey(for: provider)
        return Button {
            Haptics.tap()
            saveCurrent()                 // persist edits to the previous provider
            selected = provider
            loadProvider(provider)
            appState.activeProvider = provider
        } label: {
            VStack(spacing: 6) {
                Image(systemName: provider.symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(provider.displayName)
                    .font(Theme.Font.caption(12))
                if configured {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Palette.success)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(isSelected ? .white : Theme.textSecondary(scheme))
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.energyGradient)
                                     : AnyShapeStyle(Theme.chipFill(scheme)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.glassBorder(scheme), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: API key

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: selected.symbol).foregroundStyle(Theme.Palette.brand)
                Text("\(selected.displayName) · \(selected.maker)")
                    .font(Theme.Font.title(16))
                    .foregroundStyle(Theme.textPrimary(scheme))
            }
            Text("ai.keyLabel")
                .font(Theme.Font.caption(12))
                .foregroundStyle(Theme.textSecondary(scheme))
            SecureField(selected.keyPlaceholder, text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Theme.chipFill(scheme),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            Label("ai.getKey \(selected.consoleURL)", systemImage: "link")
                .font(Theme.Font.caption(12))
                .foregroundStyle(Theme.Palette.brand)
            HStack {
                Label("ai.privacy", systemImage: "lock.fill")
                    .font(Theme.Font.caption(11))
                    .foregroundStyle(Theme.textSecondary(scheme))
                Spacer()
                if appState.hasKey(for: selected) {
                    Button("ai.removeKey") {
                        key = ""
                        appState.setAPIKey(nil, for: selected)
                        Haptics.tap()
                    }
                    .font(Theme.Font.caption(12))
                    .foregroundStyle(Theme.Palette.danger)
                }
            }
        }
        .cardSurface()
    }

    // MARK: Model

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ai.model")
                .font(Theme.Font.title(16))
                .foregroundStyle(Theme.textPrimary(scheme))
            FlowChips(items: selected.models, selected: model) { picked in
                Haptics.tap()
                model = picked
                appState.setModel(picked, for: selected)
            }
            Text("ai.modelCustom")
                .font(Theme.Font.caption(12))
                .foregroundStyle(Theme.textSecondary(scheme))
            TextField(selected.defaultModel, text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .background(Theme.chipFill(scheme),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .onChange(of: model) { _, newValue in
                    appState.setModel(newValue, for: selected)
                }
        }
        .cardSurface()
    }

    // MARK: Helpers

    private func loadProvider(_ provider: AIProvider) {
        key = appState.apiKey(for: provider) ?? ""
        model = appState.model(for: provider)
    }

    private func saveCurrent() {
        appState.setAPIKey(key, for: selected)
        if !model.isEmpty { appState.setModel(model, for: selected) }
    }
}

/// Simple wrapping row of selectable chips.
struct FlowChips: View {
    @Environment(\.colorScheme) private var scheme
    var items: [String]
    var selected: String
    var onSelect: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected == item
                Button { onSelect(item) } label: {
                    Text(item)
                        .font(Theme.Font.caption(12))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? .white : Theme.textPrimary(scheme))
                        .background(
                            Capsule().fill(isSelected ? AnyShapeStyle(Theme.energyGradient)
                                                      : AnyShapeStyle(Theme.chipFill(scheme)))
                        )
                        .overlay(Capsule().strokeBorder(Theme.glassBorder(scheme),
                                                        lineWidth: isSelected ? 0 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
