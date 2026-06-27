import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var conn: ConnectionManager
    @Environment(\.openWindow) private var openWindow

    private var theme: Color { AppTheme.color(for: store.settings.accentColorName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()

            if store.data.profiles.isEmpty {
                Text("No servers yet.").foregroundStyle(.secondary).font(.callout)
                Button("Add a server…") { openWindow(id: "main") }
            } else {
                Picker("Server", selection: selectionBinding) {
                    ForEach(store.data.profiles) { Text($0.name).tag($0.id as String?) }
                }
                .labelsHidden()
                .disabled(conn.state.isConnected || conn.state.isBusy)

                connectButton

                if conn.state.isConnected { statsCard }
            }

            if let warning = conn.warning {
                Text(warning).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 310)
        .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
            openWindow(id: "main")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: conn.state.isConnected ? "bolt.fill" : "bolt.slash.fill")
                .foregroundStyle(conn.state.isConnected ? .green : .secondary)
            Text("Amir V2ray").font(.headline)
            Spacer()
            StatusDot(state: conn.state)
        }
    }

    private var connectButton: some View {
        Button {
            conn.toggle(store.selected, settings: store.settings)
        } label: {
            HStack {
                if conn.state.isBusy { ProgressView().controlSize(.small) }
                Text(conn.state.isConnected || conn.state.isBusy ? "Disconnect" : "Connect")
                    .frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(conn.state.isConnected ? .red : theme)
    }

    private var statsCard: some View {
        VStack(spacing: 8) {
            HStack {
                if let info = conn.exitInfo, !info.country.isEmpty {
                    Text(flagEmoji(info.code))
                    Text(info.country).fontWeight(.medium)
                } else {
                    Text("Locating…").foregroundStyle(.secondary)
                }
                Spacer()
                if let since = conn.connectedSince {
                    Text(since, style: .timer).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            Divider()
            HStack {
                Label(formatBytes(conn.downSpeed, perSecond: true), systemImage: "arrow.down")
                    .foregroundStyle(.green)
                Spacer()
                Label(formatBytes(conn.upSpeed, perSecond: true), systemImage: "arrow.up")
                    .foregroundStyle(.blue)
            }
            .font(.caption.monospacedDigit())
            HStack {
                Text("Data used").foregroundStyle(.secondary)
                Spacer()
                Text("↓ \(formatBytes(conn.downTotal))   ↑ \(formatBytes(conn.upTotal))").monospacedDigit()
            }
            .font(.caption)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack {
            Button { openWindow(id: "main") } label: { Label("Open", systemImage: "macwindow") }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .font(.callout)
        .buttonStyle(.borderless)
        .tint(.secondary)            // readable on any theme
    }

    private var selectionBinding: Binding<String?> {
        Binding(get: { store.selected?.id }, set: { if let id = $0 { store.select(id) } })
    }
}

struct StatusDot: View {
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
        case .connecting: return .orange
        case .error: return .red
        case .disconnected: return .secondary
        }
    }
    private var text: String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .error: return "Error"
        case .disconnected: return "Off"
        }
    }
}
