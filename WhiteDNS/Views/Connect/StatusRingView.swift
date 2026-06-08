import SwiftUI

struct StatusRingView: View {
    let status: ConnectionStatus
    @State private var spin = 0.0
    @State private var pulse = false

    var ringColor: Color {
        switch status {
        case .connected:          return .wdSuccess
        case .connecting:         return .wdAccent
        case .disconnecting:      return .wdWarning
        case .disconnected:       return Color(hex: "2D3340")!
        }
    }

    var label: String {
        switch status {
        case .connected:               return "متصل"
        case .connecting(let p, _):    return p
        case .disconnecting:           return "در حال قطع…"
        case .disconnected:            return "قطع"
        }
    }

    var progress: Double {
        if case .connecting(_, let p) = status { return p }
        return 0
    }

    var body: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(ringColor.opacity(status.isConnected ? 0.12 : 0.04))
                .frame(width: 220, height: 220)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

            // Static outer ring
            Circle()
                .stroke(ringColor.opacity(0.22), lineWidth: 1.5)
                .frame(width: 198, height: 198)

            // Animated progress arc (connecting)
            if case .connecting = status {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(colors: [.wdAccent.opacity(0), .wdAccent], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 198, height: 198)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(.wdAccent.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(spin))
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: spin)
            }

            // Connected ring
            if status.isConnected {
                Circle()
                    .stroke(
                        LinearGradient(colors: [.wdSuccess, .wdSuccess.opacity(0.4)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2.5
                    )
                    .frame(width: 198, height: 198)
            }

            // Inner card
            Circle()
                .fill(Color.wdSurface)
                .frame(width: 158, height: 158)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)

            // Content
            VStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(ringColor)
                    .symbolEffect(.pulse, isActive: status.isConnected)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(status.isConnected ? .wdSuccess : .wdMuted)
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
            }
        }
        .onAppear {
            pulse = status.isConnected
            if case .connecting = status { spin = 360 }
        }
        .onChange(of: status) { _, new in
            pulse = new.isConnected
            if case .connecting = new { spin = spin == 0 ? 360 : 0; DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { spin = 360 } }
        }
        .animation(.easeInOut(duration: 0.5), value: status.isConnected)
    }

    private var iconName: String {
        switch status {
        case .connected:    return "wifi"
        case .connecting:   return "arrow.triangle.2.circlepath"
        case .disconnecting:return "arrow.triangle.2.circlepath"
        case .disconnected: return "wifi.slash"
        }
    }
}
