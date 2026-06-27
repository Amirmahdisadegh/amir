import SwiftUI
import AppKit

struct ServersTab: View {
    @EnvironmentObject var store: ProfileStore

    @State private var editing: ServerProfile?
    @State private var showImport = false
    @State private var importText = ""
    @State private var alert: AlertItem?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if store.data.servers.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.data.servers) { server in
                        ServerRow(server: server,
                                  isSelected: server.id == store.selectedServer?.id,
                                  onSelect: { store.selectServer(server.id) },
                                  onEdit: { editing = server },
                                  onCopyLink: { copyLink(server) },
                                  onDelete: { store.deleteServer(server.id) })
                    }
                }
            }
        }
        .sheet(item: $editing) { server in
            ServerEditor(server: server) { store.upsertServer($0) }
        }
        .sheet(isPresented: $showImport) {
            ImportSheet(text: $importText) { performImport($0) }
        }
        .alert(item: $alert) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
        .onReceive(NotificationCenter.default.publisher(for: .stormdnsLinkOpened)) { note in
            if let link = note.object as? String { performImport(link) }
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Server Profiles").font(.headline)
            Spacer()
            Button { showImport = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
            Button { editing = ServerProfile(label: "New Server", domain: "", encryptionKey: "") } label: {
                Label("Add", systemImage: "plus")
            }
        }
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "server.rack").font(.largeTitle).foregroundStyle(.secondary)
            Text("No server profiles").font(.headline)
            Text("Import a stormdns:// link or add a profile manually.")
                .foregroundStyle(.secondary).font(.callout)
            HStack {
                Button("Import link…") { showImport = true }
                Button("Add manually…") {
                    editing = ServerProfile(label: "New Server", domain: "", encryptionKey: "")
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func performImport(_ raw: String) {
        do {
            let profile = try ProfileLink.parse(raw)
            store.upsertServer(profile)
            store.selectServer(profile.id)
            importText = ""
            showImport = false
            alert = AlertItem(title: "Imported", message: "Added “\(profile.label)”.")
        } catch {
            alert = AlertItem(title: "Import failed", message: error.localizedDescription)
        }
    }

    private func copyLink(_ server: ServerProfile) {
        let link = ProfileLink.build(from: server)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
        alert = AlertItem(title: "Copied", message: "stormdns:// link copied to the clipboard.")
    }
}

private struct ServerRow: View {
    let server: ServerProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onCopyLink: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .onTapGesture(perform: onSelect)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.label).fontWeight(.medium)
                Text("\(server.domain) · \(server.method.label)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Edit…", action: onEdit)
                Button("Copy stormdns:// link", action: onCopyLink)
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .padding(.vertical, 4)
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
