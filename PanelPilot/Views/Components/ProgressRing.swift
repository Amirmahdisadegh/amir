import SwiftUI

/// Circular progress ring used for client traffic percentage.
struct ProgressRing: View {
    let fraction: Double
    var size: CGFloat = 44
    var lineWidth: CGFloat = 5
    var showLabel: Bool = true

    private var clamped: Double { min(max(fraction, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    Theme.trafficGradient(for: clamped),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Theme.spring, value: clamped)
            if showLabel {
                Text(Fmt.percent(clamped))
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Linear traffic bar with a gradient fill and rounded ends.
struct TrafficBar: View {
    let fraction: Double
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Theme.trafficGradient(for: fraction))
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
                    .animation(Theme.spring, value: fraction)
            }
        }
        .frame(height: height)
    }
}

/// Status dot with a soft glow.
struct StatusDot: View {
    let color: Color
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.7), radius: 4)
    }
}
