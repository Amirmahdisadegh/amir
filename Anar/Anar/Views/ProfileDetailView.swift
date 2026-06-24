import SwiftUI

struct ProfileDetailView: View {
    let profile: ProxyProfile
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var conn: ConnectionManager

    private var isActiveProfile: Bool { conn.activeName == profile.name }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                if conn.state.isConnected && isActiveProfile { liveStats }
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
            ZStack {
                Circle().fill(ringColor.opacity(0.15)).frame(width: 128, height: 128)
                Circle().strokeBorder(ringColor.opacity(0.5), lineWidth: 2).frame(width: 128, height: 128)
                Image(systemName: conn.state.isConnected && isActiveProfile ? "bolt.horizontal.fill" : "bolt.horizontal")
                    .font(.system(size: 44)).foregroundStyle(ringColor)
            }
            Text(profile.name.isEmpty ? profile.server : profile.name).font(.title2.bold())
            Text(statusText).foregroundStyle(.secondary)

            Button {
                store.select(profile.id)
                conn.toggle(profile, settings: store.settings)
            } label: {
                HStack {
                    if conn.state.isBusy && isActiveProfile { ProgressView().controlSize(.small) }
                    Text(buttonTitle).frame(maxWidth: .infinity)
                }
                .frame(height: 22)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(conn.state.isConnected && isActiveProfile ? .red : .accentColor)
            .frame(maxWidth: 260)
            .disabled(!profile.isValid)

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
