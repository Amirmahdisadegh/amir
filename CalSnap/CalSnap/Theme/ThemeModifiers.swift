import SwiftUI

// MARK: - Reusable view styling

/// Frosted-glass card surface used across the app. Reads as translucent glass
/// over the colorful aurora background, with a bright edge highlight.
struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        // Translucent frosted panel over the colourful aurora — reads as glass
        // but uses NO live blur, so scrolling stays perfectly smooth.
        let g = Theme.glassIntensity                 // 0 = solid, 1 = very see-through
        var panelOpacity = scheme == .dark ? (0.40 + (1 - g) * 0.5)
                                           : (0.55 + (1 - g) * 0.4)
        if Theme.backgroundStyle == .photo { panelOpacity = max(panelOpacity, 0.72) }
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .padding(padding)
            .background(shape.fill(Theme.surface(scheme).opacity(panelOpacity)))
            // Decorative sheen + border — must NOT intercept touches.
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            colors: scheme == .dark
                                ? [Color.white.opacity(0.10), Color.white.opacity(0.02)]
                                : [Color.white.opacity(0.45), Color.white.opacity(0.10)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                shape.strokeBorder(Theme.glassBorder(scheme), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.20 : 0.07),
                    radius: 7, x: 0, y: 3)
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
