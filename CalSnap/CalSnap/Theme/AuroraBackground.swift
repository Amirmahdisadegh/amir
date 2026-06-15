import SwiftUI

/// A colorful, softly-blurred backdrop that gives the glass surfaces something
/// vivid to refract. Rendered once on the GPU (drawingGroup) and kept static so
/// it never re-blurs while scrolling — that keeps the UI smooth.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme

    private var base: Color {
        switch Theme.backgroundStyle {
        case .black: return .black
        default:     return scheme == .dark ? Color(hex: 0x080A0F) : Color(hex: 0xEAEFF6)
        }
    }

    /// Blob opacity multiplier per style (0 hides the blobs entirely).
    private var blobStrength: Double {
        switch Theme.backgroundStyle {
        case .aurora:   return 1.0
        case .vivid:    return 1.6
        case .black:    return 0.55   // faint glow over pure black
        case .graphite: return 0.0    // flat, no blobs
        case .photo:    return 0.0    // photo provides the backdrop
        }
    }

    var body: some View {
        ZStack {
            base
            if Theme.backgroundStyle == .photo, let img = Theme.backgroundImage {
                GeometryReader { geo in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                LinearGradient(colors: [Color.black.opacity(0.45), Color.black.opacity(0.65)],
                               startPoint: .top, endPoint: .bottom)
            }
            if Theme.backgroundStyle == .graphite {
                Theme.heroGradient(scheme)
            }
            if blobStrength > 0 {
                blobs(strength: blobStrength)
                    .drawingGroup()       // composite the heavy blur once on the GPU
            }
        }
        .ignoresSafeArea()
    }

    private func blobs(strength k: Double) -> some View {
        ZStack {
            blob(Theme.Palette.brand,   nx: -0.55, ny: -0.55, scale: 1.15,
                 opacity: (scheme == .dark ? 0.55 : 0.65) * k)
            blob(Theme.Palette.aurora1, nx:  0.65, ny: -0.30, scale: 0.95,
                 opacity: (scheme == .dark ? 0.40 : 0.50) * k)
            blob(Theme.Palette.aurora2, nx:  0.55, ny:  0.55, scale: 1.05,
                 opacity: (scheme == .dark ? 0.35 : 0.45) * k)
            blob(Theme.Palette.aurora3, nx: -0.50, ny:  0.65, scale: 0.85,
                 opacity: (scheme == .dark ? 0.30 : 0.45) * k)
            blob(Theme.Palette.aurora4, nx: -0.10, ny:  0.05, scale: 0.70,
                 opacity: (scheme == .dark ? 0.28 : 0.30) * k)
        }
    }

    private func blob(_ color: Color, nx: CGFloat, ny: CGFloat, scale: CGFloat,
                      opacity: Double) -> some View {
        GeometryReader { geo in
            let d = geo.size.width * scale
            Circle()
                .fill(color)
                .frame(width: d, height: d)
                .position(x: geo.size.width * (0.5 + nx * 0.5),
                          y: geo.size.height * (0.5 + ny * 0.5))
                .blur(radius: 90)
                .opacity(opacity)
        }
    }
}

#Preview {
    AuroraBackground()
}
