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
                Section("Routing") {
                    Picker("Mode", selection: s.mode) {
                        ForEach(RoutingMode.allCases, id: \.self) { Text($0.display).tag($0) }
                    }
                    Text(store.settings.mode == .tun
                         ? "TUN routes ALL system traffic through the tunnel (asks for your password to start)."
                         : "System Proxy routes browser/app traffic via a local SOCKS/HTTP proxy (no password needed).")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Bypass private / LAN addresses", isOn: s.bypassPrivate)
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
