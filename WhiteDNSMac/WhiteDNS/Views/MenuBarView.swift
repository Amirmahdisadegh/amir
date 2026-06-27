import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var tunnel: TunnelController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            if store.data.servers.isEmpty {
                emptyState
            } else {
                serverPicker
                connectButton
                if tunnel.state.isConnected { trafficRow }
            }

            if let warning = tunnel.warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button("Open WhiteDNS…") { openWindow(id: "main") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(.tint)
            Text("WhiteDNS").font(.headline)
            Spacer()
            StatusBadge(state: tunnel.state)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No server profiles yet.").foregroundStyle(.secondary)
            Button("Add or import a profile…") { openWindow(id: "main") }
        }
        .font(.callout)
    }

    private var serverPicker: some View {
        Picker("Server", selection: serverBinding) {
            ForEach(store.data.servers) { s in
                Text(s.label).tag(s.id as String?)
            }
        }
        .labelsHidden()
        .disabled(tunnel.state.isConnected || tunnel.state.isBusy)
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
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(tunnel.state.isConnected ? .red : .accentColor)
        .disabled(store.selectedServer == nil)
    }

    private var trafficRow: some View {
        HStack(spacing: 18) {
            Label(tunnel.traffic.downloadSpeed, systemImage: "arrow.down")
                .foregroundStyle(.green)
            Label(tunnel.traffic.uploadSpeed, systemImage: "arrow.up")
                .foregroundStyle(.blue)
        }
        .font(.callout.monospacedDigit())
    }

    private var serverBinding: Binding<String?> {
        Binding(
            get: { store.selectedServer?.id },
            set: { if let id = $0 { store.selectServer(id) } }
        )
    }
}

struct StatusBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch state {
        case .connected: return .green
        case .starting: return .orange
        case .error: return .red
        case .disconnected: return .secondary
        }
    }

    private var text: String {
        switch state {
        case .connected: return "Connected"
        case .starting: return "Connecting"
        case .error: return "Error"
        case .disconnected: return "Off"
        }
    }
}
