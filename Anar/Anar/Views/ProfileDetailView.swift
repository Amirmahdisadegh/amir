import SwiftUI
import Charts

struct ProfileDetailView: View {
    let profile: ProxyProfile
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var conn: ConnectionManager

    private var isActiveProfile: Bool { conn.activeName == profile.name }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                if conn.state.isConnected && isActiveProfile {
                    liveStats
                    trafficChart
                }
                infoCard
                if let warning = conn.warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            // Big tappable power button (ExpressVPN-style).
            Button {
                guard profile.isValid else { return }
                store.select(profile.id)
                conn.toggle(profile, settings: store.settings)
            } label: {
                ZStack {
                    Circle().fill(ringColor.opacity(0.12)).frame(width: 168, height: 168)
                    Circle().strokeBorder(ringColor.opacity(0.55), lineWidth: 6).frame(width: 168, height: 168)
                    if conn.state.isBusy && isActiveProfile {
                        ProgressView().controlSize(.large)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 58, weight: .semibold))
                            .foregroundStyle(ringColor)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!profile.isValid)

            Text(heroStatusText.uppercased())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ringColor)
                .tracking(1.5)

            // Connected location (flag + country + IP) and live timer.
            if conn.state.isConnected && isActiveProfile {
                if let info = conn.exitInfo, !info.country.isEmpty {
                    HStack(spacing: 8) {
                        Text(flagEmoji(info.code)).font(.system(size: 30))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(info.country).font(.title3.bold())
                            Text(info.ip).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Locating exit…").foregroundStyle(.secondary)
                    }
                }
                if let since = conn.connectedSince {
                    Text(since, style: .timer)
                        .font(.title2.monospacedDigit().weight(.medium))
                }
            } else {
                Text(profile.name.isEmpty ? profile.server : profile.name).font(.title2.bold())
                Text(profile.subtitle).font(.callout).foregroundStyle(.secondary)
            }

            if !profile.isValid {
                Text("This profile is missing required fields.").font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var liveStats: some View {
        HStack(spacing: 14) {
            statCard("Download", formatBytes(conn.downSpeed, perSecond: true), formatBytes(conn.downTotal), "arrow.down", .green)
            statCard("Upload", formatBytes(conn.upSpeed, perSecond: true), formatBytes(conn.upTotal), "arrow.up", .blue)
            VStack(spacing: 6) {
                Label(conn.latencyMs.map { "\($0) ms" } ?? "—", systemImage: "speedometer")
                    .font(.headline.monospacedDigit())
                Button("Test") { conn.testLatency() }.controlSize(.small).buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var trafficChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live traffic").font(.caption).foregroundStyle(.secondary)
            Chart(conn.trafficSamples) { sample in
                AreaMark(x: .value("t", sample.date), y: .value("down", sample.down), series: .value("s", "Download"))
                    .foregroundStyle(.green.opacity(0.25))
                LineMark(x: .value("t", sample.date), y: .value("down", sample.down), series: .value("s", "Download"))
                    .foregroundStyle(.green)
                LineMark(x: .value("t", sample.date), y: .value("up", sample.up), series: .value("s", "Upload"))
                    .foregroundStyle(.blue)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) { Text(formatBytes(v, perSecond: true)).font(.caption2) }
                    }
                }
            }
            .frame(height: 120)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statCard(_ title: String, _ rate: String, _ total: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Label(rate, systemImage: icon).font(.headline.monospacedDigit()).foregroundStyle(color)
            Text(total).font(.caption).foregroundStyle(.secondary)
            Text(title).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var infoCard: some View {
        GroupBox {
            VStack(spacing: 0) {
                infoRow("Type", profile.type.display)
                Divider()
                infoRow("Address", "\(profile.server):\(profile.port)")
                if profile.tls || profile.reality {
                    Divider(); infoRow("Security", profile.reality ? "REALITY" : "TLS" + (profile.sni.isEmpty ? "" : " · \(profile.sni)"))
                }
                if profile.network != "tcp" {
                    Divider(); infoRow("Transport", profile.network.uppercased())
                }
                Divider(); infoRow("Routing", store.settings.mode.display)
            }
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.callout)
        .padding(.vertical, 7)
    }

    private var heroStatusText: String {
        guard isActiveProfile else { return "Disconnected" }
        switch conn.state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .error: return "Error"
        case .disconnected: return "Disconnected"
        }
    }

    private var ringColor: Color {
        if conn.state.isConnected && isActiveProfile { return .green }
        if conn.state.isBusy && isActiveProfile { return .orange }
        return .secondary
    }

    private var statusText: String {
        if isActiveProfile {
            switch conn.state {
            case .connected: return "Connected"
            case .connecting: return "Connecting…"
            case .error(let m): return m
            case .disconnected: return profile.subtitle
            }
        }
        return profile.subtitle
    }

    private var buttonTitle: String {
        if conn.state.isConnected && isActiveProfile { return "Disconnect" }
        if conn.state.isBusy && isActiveProfile { return "Connecting…" }
        return "Connect"
    }
}
