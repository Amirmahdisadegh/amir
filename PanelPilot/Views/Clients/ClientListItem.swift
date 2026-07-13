import SwiftUI

/// A client row inside a `List` with swipe actions, confirmation dialogs, and a
/// navigation link into the client detail. Centralises mutation handling so both
/// the inbound detail and the global Clients tab behave identically.
struct ClientListItem: View {
    let row: ClientRow
    var showInbound: Bool = false
    @Binding var toast: ToastData?

    @Environment(AppState.self) private var app
    private var store: DataStore { app.store }

    @State private var confirmDelete = false
    @State private var confirmReset = false
    @State private var isWorking = false

    var body: some View {
        NavigationLink(value: row) {
            ClientRowView(row: row, showInbound: showInbound)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Haptics.warning(); confirmDelete = true
            } label: { Label("common.delete".loc, systemImage: "trash") }

            Button {
                Haptics.tap(); toggle()
            } label: {
                Label(row.client.enable ? "common.disabled".loc : "common.enabled".loc,
                      systemImage: row.client.enable ? "pause.circle" : "play.circle")
            }
            .tint(row.client.enable ? Theme.offline : Theme.online)
        }
        .swipeActions(edge: .leading) {
            Button {
                Haptics.tap(); confirmReset = true
            } label: { Label("client.reset_traffic".loc, systemImage: "arrow.counterclockwise") }
            .tint(Theme.accentIndigo)
        }
        .confirmationDialog("client.delete_confirm_title".loc,
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("common.delete".loc, role: .destructive) { delete() }
            Button("common.cancel".loc, role: .cancel) {}
        } message: {
            Text("client.delete_confirm_msg".loc(row.client.email))
        }
        .confirmationDialog("client.reset_confirm_title".loc,
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button("client.reset_traffic".loc) { reset() }
            Button("common.cancel".loc, role: .cancel) {}
        } message: {
            Text("client.reset_confirm_msg".loc(row.client.email))
        }
    }

    private func toggle() {
        Task {
            do {
                try await store.toggleClient(inboundId: row.inbound.id, client: row.client)
                toast = ToastData(message: "toast.client_updated".loc)
            } catch { toast = ToastData(message: (error as? APIError)?.errorDescription ?? "",
                                        symbol: "exclamationmark.triangle") }
        }
    }

    private func delete() {
        Task {
            do {
                try await store.deleteClient(inboundId: row.inbound.id, client: row.client)
                toast = ToastData(message: "toast.client_deleted".loc, symbol: "trash")
            } catch { toast = ToastData(message: (error as? APIError)?.errorDescription ?? "",
                                        symbol: "exclamationmark.triangle") }
        }
    }

    private func reset() {
        Task {
            do {
                try await store.resetTraffic(inboundId: row.inbound.id, email: row.client.email)
                toast = ToastData(message: "toast.traffic_reset".loc, symbol: "arrow.counterclockwise")
            } catch { toast = ToastData(message: (error as? APIError)?.errorDescription ?? "",
                                        symbol: "exclamationmark.triangle") }
        }
    }
}
