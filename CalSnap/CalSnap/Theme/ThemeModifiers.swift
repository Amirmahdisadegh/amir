import SwiftUI

// MARK: - Reusable view styling

/// Frosted-glass card surface used across the app. Reads as translucent glass
/// over the colorful aurora background, with a bright edge highlight.
struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        // Lower intensity → more solid panel; higher → barely-there glass.
        let solidOpacity = (1 - Theme.glassIntensity) * 0.9
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .padding(padding)
            .background(shape.fill(.ultraThinMaterial))
            // Solid backing that fades out as the glass gets more translucent.
            .background(shape.fill(Theme.surface(scheme).opacity(solidOpacity)))
            // Subtle inner tint + top sheen for a glassier read.
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: scheme == .dark
                            ? [Color.white.opacity(0.10), Color.white.opacity(0.02)]
                            : [Color.white.opacity(0.45), Color.white.opacity(0.10)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .overlay(shape.strokeBorder(Theme.glassBorder(scheme), lineWidth: 1))
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.45 : 0.12),
                    radius: 20, x: 0, y: 12)
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
