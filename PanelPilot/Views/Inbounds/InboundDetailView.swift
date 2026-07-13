import SwiftUI

struct InboundDetailView: View {
    let inboundId: Int
    @Environment(AppState.self) private var app
    private var store: DataStore { app.store }

    @State private var toast: ToastData?
    @State private var showAdd = false

    private var inbound: Inbound? { store.inbound(withId: inboundId) }
    private var rows: [ClientRow] { store.clientRows(forInbound: inboundId) }

    var body: some View {
        Group {
            if let inbound {
                List {
                    Section {
                        InboundSummaryCard(inbound: inbound)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    Section {
                        if rows.isEmpty {
                            EmptyStateView(systemImage: "person.crop.circle.badge.plus",
                                           title: "clients.empty".loc,
                                           message: "clients.empty_hint".loc)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(rows) { row in
                                ClientListItem(row: row, toast: $toast)
                            }
                        }
                    } header: {
                        Text(Fmt.digits("clients.count".loc(rows.count)))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                EmptyStateView(systemImage: "tray", title: "inbounds.empty".loc)
            }
        }
        .background(ScreenBackground())
        .navigationTitle(inbound?.remark ?? "inbounds.title".loc)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.tap(); showAdd = true
                } label: { Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accentGradient) }
            }
        }
        .navigationDestination(for: ClientRow.self) { row in
            ClientDetailView(inboundId: row.inbound.id, clientId: row.client.id)
        }
        .sheet(isPresented: $showAdd) {
            if let inbound {
                ClientEditorView(inbound: inbound, existing: nil, toast: $toast)
            }
        }
        .refreshable { await store.refreshAll() }
        .toast($toast)
    }
}

struct InboundSummaryCard: View {
    let inbound: Inbound

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(inbound.`protocol`.uppercased(), systemImage: "shield.lefthalf.filled")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.accentGradient, in: Capsule())
                    Spacer()
                    HStack(spacing: 6) {
                        StatusDot(color: inbound.enable ? Theme.online : Theme.offline)
                        Text(inbound.enable ? "common.enabled".loc : "common.disabled".loc)
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                HStack(spacing: 20) {
                    stat("inbounds.port".loc(""), Fmt.digits(String(inbound.port)), "number")
                    stat("dashboard.network".loc, inbound.stream.network.uppercased(), "network")
                    stat("settings.security".loc, inbound.stream.security.uppercased(), "lock.shield")
                }
                Divider().overlay(Theme.cardStroke)
                HStack {
                    trafficStat("arrow.up.circle.fill", Fmt.bytes(inbound.up),
                                "dashboard.upload".loc, Theme.accentIndigo)
                    Spacer()
                    trafficStat("arrow.down.circle.fill", Fmt.bytes(inbound.down),
                                "dashboard.download".loc, Theme.accentCyan)
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(Theme.textPrimary)
            Text(title).font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trafficStat(_ symbol: String, _ value: String, _ title: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Text(title).font(.caption2).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        InboundDetailView(inboundId: 1)
            .environment(AppState.preview())
    }
    .preferredColorScheme(.dark)
}
