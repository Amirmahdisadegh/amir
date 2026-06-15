import SwiftUI

/// A colorful, softly-blurred backdrop that gives the glass surfaces something
/// vivid to refract. Used behind every main screen.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme
    var animated: Bool = true
    @State private var drift = false

    private var base: Color {
        scheme == .dark ? Color(hex: 0x080A0F) : Color(hex: 0xEAEFF6)
    }

    var body: some View {
        ZStack {
            base
            blob(Theme.Palette.brand,   nx: -0.55, ny: -0.55, scale: 1.15,
                 opacity: scheme == .dark ? 0.55 : 0.65, drifted: drift)
            blob(Theme.Palette.aurora1, nx:  0.65, ny: -0.30, scale: 0.95,
                 opacity: scheme == .dark ? 0.40 : 0.50, drifted: !drift)
            blob(Theme.Palette.aurora2, nx:  0.55, ny:  0.55, scale: 1.05,
                 opacity: scheme == .dark ? 0.35 : 0.45, drifted: drift)
            blob(Theme.Palette.aurora3, nx: -0.50, ny:  0.65, scale: 0.85,
                 opacity: scheme == .dark ? 0.30 : 0.45, drifted: !drift)
            blob(Theme.Palette.aurora4, nx: -0.10, ny:  0.05, scale: 0.70,
                 opacity: scheme == .dark ? 0.28 : 0.30, drifted: drift)
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                drift.toggle()
            }
        }
    }

    private func blob(_ color: Color, nx: CGFloat, ny: CGFloat, scale: CGFloat,
                      opacity: Double, drifted: Bool) -> some View {
        GeometryReader { geo in
            let d = geo.size.width * scale
            let dx = drifted ? 0.08 : -0.06
            let dy = drifted ? -0.05 : 0.07
            Circle()
                .fill(color)
                .frame(width: d, height: d)
                .position(x: geo.size.width * (0.5 + (nx + dx) * 0.5),
                          y: geo.size.height * (0.5 + (ny + dy) * 0.5))
                .blur(radius: 100)
                .opacity(opacity)
        }
    }
}

#Preview {
    AuroraBackground()
}
