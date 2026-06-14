import SwiftUI

// MARK: - Reusable view styling

/// Frosted-glass card surface used across the app. Reads as translucent glass
/// over the colorful aurora background, with a bright edge highlight.
struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.glassBorder(scheme), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.10),
                    radius: 18, x: 0, y: 10)
    }
}

extension View {
    func cardSurface(padding: CGFloat = Theme.Space.md,
                     radius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(CardSurface(padding: padding, radius: radius))
    }
}

/// Primary capsule button used for main calls to action.
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.energyGradient
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.title(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// Subtle bordered secondary button.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.title(16))
            .foregroundStyle(Theme.textPrimary(scheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.surfaceElevated(scheme), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.separator(scheme), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
