import SwiftUI
import UIKit

struct ClientDetailView: View {
    let inboundId: Int
    let clientId: String

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    private var store: DataStore { app.store }

    @State private var toast: ToastData?
    @State private var showEdit = false
    @State private var showShare = false
    @State private var confirmDelete = false
    @State private var confirmReset = false

    private var inbound: Inbound? { store.inbound(withId: inboundId) }
    private var row: ClientRow? { store.clientRows(forInbound: inboundId).first { $0.client.id == clientId } }

    private var connectionURI: String {
        guard let inbound, let row else { return "" }
        return ConnectionURIBuilder.uri(for: row.client, inbound: inbound,
                                        serverAddress: app.config.host)
    }

    var body: some View {
        ScrollView {
            if let row {
                VStack(spacing: 16) {
                    headerCard(row)
                    usageCard(row)
                    qrCard
                    uriCard
                    actionButtons(row)
                }
                .padding()
            } else {
                EmptyStateView(systemImage: "person.slash", title: "clients.empty".loc)
                    .padding(.top, 60)
            }
        }
        .background(ScreenBackground())
        .scrollContentBackground(.hidden)
        .navigationTitle(row?.client.email ?? "clients.title".loc)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.tap(); showEdit = true
                } label: { Image(systemName: "square.and.pencil").foregroundStyle(Theme.accentGradient) }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let inbound, let row {
                ClientEditorView(inbound: inbound, existing: row.client, toast: $toast)
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [connectionURI])
        }
        .confirmationDialog("client.delete_confirm_title".loc,
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("common.delete".loc, role: .destructive) { delete() }
            Button("common.cancel".loc, role: .cancel) {}
        } message: { Text("client.delete_confirm_msg".loc(row?.client.email ?? "")) }
        .confirmationDialog("client.reset_confirm_title".loc,
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button("client.reset_traffic".loc) { reset() }
            Button("common.cancel".loc, role: .cancel) {}
        } message: { Text("client.reset_confirm_msg".loc(row?.client.email ?? "")) }
        .refreshable { await store.refreshAll() }
        .toast($toast)
    }

    // MARK: - Cards

    private func headerCard(_ row: ClientRow) -> some View {
        GlassCard {
            VStack(spacing: 14) {
                ProgressRing(fraction: row.trafficFraction, size: 96, lineWidth: 10)
                HStack(spacing: 8) {
                    StatusDot(color: row.statusColor, size: 10)
                    Text(statusText(row))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func usageCard(_ row: ClientRow) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "client.usage".loc, symbol: "chart.bar.fill")
                TrafficBar(fraction: row.trafficFraction, height: 8)
                Text(Fmt.trafficUsage(used: row.used, limit: row.limit))
                    .font(.subheadline).foregroundStyle(Theme.textPrimary)
                Divider().overlay(Theme.cardStroke)
                infoRow("client.expiry_date".loc, Fmt.date(row.client.expiryTime), "calendar")
                infoRow("client.email".loc, row.client.email, "envelope")
                infoRow("client.uuid".loc, row.client.id, "number", copyable: true)
                if !row.client.flow.isEmpty {
                    infoRow("client.flow".loc, row.client.flow, "arrow.triangle.branch")
                }
            }
        }
    }

    private var qrCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                SectionHeader(title: "client.share_config".loc, symbol: "qrcode")
                QRCodeView(content: connectionURI, size: 220)
                    .frame(maxWidth: .infinity)
                Text("client.scan_qr".loc)
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var uriCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "client.connection_uri".loc, symbol: "link")
                Text(connectionURI)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                HStack(spacing: 10) {
                    Button {
                        Haptics.success()
                        UIPasteboard.general.string = connectionURI
                        toast = ToastData(message: "common.copied".loc, symbol: "doc.on.doc")
                    } label: {
                        Label("common.copy".loc, systemImage: "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    Button {
                        Haptics.tap(); showShare = true
                    } label: {
                        Label("common.share".loc, systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .foregroundStyle(.white)
                            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func actionButtons(_ row: ClientRow) -> some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap(); toggle(row)
            } label: {
                Label(row.client.enable ? "common.disabled".loc : "common.enabled".loc,
                      systemImage: row.client.enable ? "pause.circle.fill" : "play.circle.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .foregroundStyle(Theme.textPrimary)

            Button {
                Haptics.tap(); confirmReset = true
            } label: {
                Label("client.reset_traffic".loc, systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .foregroundStyle(Theme.accentCyan)

            Button {
                Haptics.warning(); confirmDelete = true
            } label: {
                Label("common.delete".loc, systemImage: "trash.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.expired.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            }
            .foregroundStyle(Theme.expired)
        }
    }

    private func infoRow(_ title: String, _ value: String, _ symbol: String,
                         copyable: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.caption).foregroundStyle(Theme.accentCyan).frame(width: 18)
            Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.caption.weight(.medium)).foregroundStyle(Theme.textPrimary)
                .lineLimit(1).truncationMode(.middle)
            if copyable {
                Button {
                    Haptics.tap()
                    UIPasteboard.general.string = value
                    toast = ToastData(message: "common.copied".loc, symbol: "doc.on.doc")
                } label: { Image(systemName: "doc.on.doc").font(.caption2) }
                .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func statusText(_ row: ClientRow) -> String {
        if !row.client.enable { return "common.disabled".loc }
        if row.isExpired { return "client.expired".loc }
        return row.isOnline ? "common.online".loc : "common.offline".loc
    }

    // MARK: - Actions

    private func toggle(_ row: ClientRow) {
        Task {
            do {
                try await store.toggleClient(inboundId: inboundId, client: row.client)
                toast = ToastData(message: "toast.client_updated".loc)
            } catch { errorToast(error) }
        }
    }
    private func reset() {
        Task {
            do {
                try await store.resetTraffic(inboundId: inboundId, email: row?.client.email ?? "")
                toast = ToastData(message: "toast.traffic_reset".loc, symbol: "arrow.counterclockwise")
            } catch { errorToast(error) }
        }
    }
    private func delete() {
        guard let client = row?.client else { return }
        Task {
            do {
                try await store.deleteClient(inboundId: inboundId, client: client)
                Haptics.success()
                dismiss()
            } catch { errorToast(error) }
        }
    }
    private func errorToast(_ error: Error) {
        Haptics.error()
        toast = ToastData(message: (error as? APIError)?.errorDescription ?? "\(error)",
                          symbol: "exclamationmark.triangle")
    }
}

#Preview {
    NavigationStack {
        ClientDetailView(inboundId: 1,
                         clientId: "9f8b1c2d-3e4f-5a6b-7c8d-9e0f1a2b3c4d")
            .environment(AppState.preview())
    }
    .preferredColorScheme(.dark)
}
