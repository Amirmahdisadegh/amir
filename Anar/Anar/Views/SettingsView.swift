import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var conn: ConnectionManager

    private var s: Binding<AppSettings> { $store.data.settings }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(20)
            Divider()

            Form {
                Section("Connection") {
                    Picker("Mode", selection: s.mode) {
                        ForEach(RoutingMode.allCases, id: \.self) { Text($0.display).tag($0) }
                    }
                    Text(store.settings.mode == .tun
                         ? "Full VPN for all traffic. Installs a small helper the first time (one password) — after that, connect/disconnect needs NO password."
                         : "Routes browser/app traffic via a local SOCKS/HTTP proxy. Asks for your password on every connect/disconnect.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Smart Routing") {
                    Picker("Rule", selection: s.routingRule) {
                        ForEach(RoutingRule.allCases, id: \.self) { Text($0.display).tag($0) }
                    }
                    Text(store.settings.routingRule == .bypassIran
                         ? "Iranian sites & IPs connect directly (fast), everything else via the tunnel. Uses auto-updating rule-sets."
                         : store.settings.routingRule == .global
                         ? "Every connection goes through the tunnel."
                         : "Only local network addresses go direct.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Block ads & trackers", isOn: s.adBlock)
                }

                Section("Ports") {
                    LabeledContent("Local proxy port (proxy mode)") {
                        TextField("", value: s.mixedPort, format: .number.grouping(.never)).frame(width: 80)
                    }
                    LabeledContent("Clash API port (stats)") {
                        TextField("", value: s.clashApiPort, format: .number.grouping(.never)).frame(width: 80)
                    }
                }

                Section("DNS") {
                    TextField("DNS server", text: s.dnsServer, prompt: Text("tls://8.8.8.8"))
                }

                Section("Appearance") {
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases) { theme in
                            Circle().fill(theme.color).frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(.primary.opacity(
                                    store.settings.accentColorName == theme.rawValue ? 0.9 : 0), lineWidth: 2))
                                .onTapGesture { store.data.settings.accentColorName = theme.rawValue }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("General") {
                    Picker("Log level", selection: s.logLevel) {
                        ForEach(AppSettings.logLevels, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Auto-connect on launch", isOn: s.autoConnectOnLaunch)
                }
            }
            .formStyle(.grouped)
            .disabled(conn.state.isConnected || conn.state.isBusy)

            if conn.state.isConnected || conn.state.isBusy {
                Text("Disconnect to change settings.").font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
            }
        }
        .frame(width: 460, height: 540)
    }
}
