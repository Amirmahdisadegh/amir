import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var conn: ConnectionManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Anar").font(.headline)
                Spacer()
                StatusDot(state: conn.state)
            }
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
                .tint(conn.state.isConnected ? .red : .accentColor)

                if conn.state.isConnected {
                    if let info = conn.exitInfo, !info.country.isEmpty {
                        HStack(spacing: 6) {
                            Text(flagEmoji(info.code))
                            Text(info.country).fontWeight(.medium)
                            Spacer()
                            if let since = conn.connectedSince {
                                Text(since, style: .timer).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .font(.callout)
                    }
                    HStack(spacing: 16) {
                        Label(formatBytes(conn.downSpeed, perSecond: true), systemImage: "arrow.down")
                            .foregroundStyle(.green)
                        Label(formatBytes(conn.upSpeed, perSecond: true), systemImage: "arrow.up")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption.monospacedDigit())
                }
            }

            Divider()
            HStack {
                Button("Open Anar…") { openWindow(id: "main") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(14)
        .frame(width: 290)
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
