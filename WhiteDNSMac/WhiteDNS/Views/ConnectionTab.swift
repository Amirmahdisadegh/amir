import SwiftUI

struct ConnectionTab: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var tunnel: TunnelController

    var body: some View {
        VStack(spacing: 20) {
            statusCard

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    pickerRow(
                        title: "Server",
                        systemImage: "server.rack",
                        selection: serverBinding,
                        options: store.data.servers.map { ($0.id, $0.label) },
                        placeholder: "No servers — add one in the Servers tab"
                    )
                    Divider()
                    pickerRow(
                        title: "Resolvers",
                        systemImage: "globe",
                        selection: resolverBinding,
                        options: store.data.resolvers.map { ($0.id, $0.name) },
                        placeholder: "No resolver sets"
                    )
                }
                .padding(6)
            }
            .disabled(tunnel.state.isConnected || tunnel.state.isBusy)

            connectButton

            if let warning = tunnel.warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
    }

    private var statusCard: some View {
        VStack(spacing: 10) {
            Image(systemName: tunnel.state.isConnected ? "shield.fill" : "shield.slash")
                .font(.system(size: 44))
                .foregroundStyle(tunnel.state.isConnected ? .green : .secondary)
            Text(tunnel.state.label).font(.title3.bold())
            if !tunnel.activeServerLabel.isEmpty && tunnel.state.isConnected {
                Text(tunnel.activeServerLabel).foregroundStyle(.secondary)
            }
            if tunnel.state.isConnected {
                HStack(spacing: 26) {
                    trafficStat("Download", tunnel.traffic.downloadSpeed, "arrow.down", .green)
                    trafficStat("Upload", tunnel.traffic.uploadSpeed, "arrow.up", .blue)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }

    private func trafficStat(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Label(value, systemImage: icon)
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var connectButton: some View {
        Button {
            guard let server = store.selectedServer else { return }
            tunnel.toggle(server: server, resolver: store.selectedResolver, settings: store.settings)
        } label: {
            HStack {
                if tunnel.state.isBusy { ProgressView().controlSize(.small) }
                Text(tunnel.state.isConnected || tunnel.state.isBusy ? "Disconnect" : "Connect")
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 22)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(tunnel.state.isConnected ? .red : .accentColor)
        .disabled(store.selectedServer == nil)
    }

    private func pickerRow(
        title: String,
        systemImage: String,
        selection: Binding<String?>,
        options: [(String, String)],
        placeholder: String
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage).frame(width: 110, alignment: .leading)
            if options.isEmpty {
                Text(placeholder).foregroundStyle(.secondary).font(.callout)
            } else {
                Picker("", selection: selection) {
                    ForEach(options, id: \.0) { Text($0.1).tag($0.0 as String?) }
                }
                .labelsHidden()
            }
            Spacer()
        }
    }

    private var serverBinding: Binding<String?> {
        Binding(get: { store.selectedServer?.id },
                set: { if let id = $0 { store.selectServer(id) } })
    }

    private var resolverBinding: Binding<String?> {
        Binding(get: { store.selectedResolver.id },
                set: { if let id = $0 { store.selectResolver(id) } })
    }
}
