import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var conn: ConnectionManager

    @State private var showAdd = false
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var alert: AlertItem?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            if let profile = store.selected {
                ProfileDetailView(profile: profile)
                    .id(profile.id)
            } else {
                ContentUnavailableView(
                    "No server selected",
                    systemImage: "bolt.horizontal.circle",
                    description: Text("Add a server with the + button, then select it.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { showAdd = true } label: { Label("Add", systemImage: "plus") }
                Button { showLogs = true } label: { Label("Logs", systemImage: "text.alignleft") }
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .sheet(isPresented: $showAdd) { AddProfileSheet { handleImport($0) } }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogsView() }
        .alert(item: $alert) { Alert(title: Text($0.title), message: Text($0.message), dismissButton: .default(Text("OK"))) }
        .onReceive(NotificationCenter.default.publisher(for: .anarLinkOpened)) { note in
            if let link = note.object as? String { handleImport(link) }
        }
    }

    private var sidebar: some View {
        List(selection: selectionBinding) {
            Section("Servers") {
                ForEach(store.data.profiles) { profile in
                    ProfileRow(profile: profile, isActive: conn.state.isConnected && conn.activeName == profile.name)
                        .tag(profile.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) { store.delete(profile.id) }
                        }
                }
            }
        }
        .overlay {
            if store.data.profiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No servers").foregroundStyle(.secondary)
                    Button("Add server…") { showAdd = true }
                }
            }
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(get: { store.selected?.id }, set: { if let id = $0 { store.select(id) } })
    }

    private func handleImport(_ raw: String) {
        // Try a single link first, then subscription/multi.
        if let one = try? LinkParser.parse(raw) {
            store.upsert(one)
            store.select(one.id)
            alert = AlertItem(title: "Imported", message: "Added “\(one.name)”.")
            return
        }
        let many = LinkParser.parseMany(raw)
        if many.isEmpty {
            alert = AlertItem(title: "Import failed", message: "No valid proxy links were found.")
        } else {
            store.add(many)
            alert = AlertItem(title: "Imported", message: "Added \(many.count) server(s).")
        }
    }
}

struct ProfileRow: View {
    let profile: ProxyProfile
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(badgeColor.opacity(0.18)).frame(width: 34, height: 34)
                Text(profile.type.display.prefix(2)).font(.caption2.bold()).foregroundStyle(badgeColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name.isEmpty ? profile.server : profile.name).fontWeight(.medium).lineLimit(1)
                Text(profile.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if isActive { Circle().fill(.green).frame(width: 8, height: 8) }
        }
        .padding(.vertical, 2)
    }

    private var badgeColor: Color {
        switch profile.type {
        case .vmess, .vless: return .purple
        case .trojan: return .orange
        case .shadowsocks: return .blue
        case .hysteria2, .tuic: return .pink
        case .wireguard: return .teal
        default: return .gray
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
