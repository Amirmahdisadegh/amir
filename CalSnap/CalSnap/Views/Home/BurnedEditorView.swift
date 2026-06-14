import SwiftUI

/// Quick sheet to set how many calories you burned today (manual, no Health needed).
struct BurnedEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var value: Int = 0

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.Palette.warning)
                Text("burned.title")
                    .font(Theme.Font.title(20))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Text("burned.subtitle")
                    .font(Theme.Font.caption(12))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }

            HStack(spacing: 14) {
                stepButton("minus") { value = max(0, value - 50) }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("0", value: $value, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(Theme.Font.mono(40))
                        .foregroundStyle(Theme.textPrimary(scheme))
                        .frame(width: 130)
                    Text("kcal")
                        .font(Theme.Font.caption(13))
                        .foregroundStyle(Theme.textSecondary(scheme))
                }
                stepButton("plus") { value += 50 }
            }

            Button("action.save") {
                appState.setBurned(value)
                Haptics.success()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.Space.lg)
        .frame(maxHeight: .infinity)
        .background(AuroraBackground())
        .onAppear { value = appState.burned() }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.Palette.brand)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.glassBorder(scheme), lineWidth: 1))
        }
    }
}
