import SwiftUI

struct InboundsView: View {
    @Environment(AppState.self) private var app
    private var store: DataStore { app.store }

    var body: some View {
        NavigationStack {
            Group {
                if store.inbounds.isEmpty {
                    if store.isLoading {
                        ScrollView { SkeletonList(count: 4).padding(.top, 8) }
                    } else if let error = store.error {
                        ScrollView {
                            ErrorStateView(error: error) { Task { await store.refreshAll() } }
                                .padding(.top, 60)
                        }
                    } else {
                        EmptyStateView(systemImage: "tray",
                                       title: "inbounds.empty".loc,
                                       message: "inbounds.empty_hint".loc)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.inbounds) { inbound in
                                NavigationLink(value: inbound.id) {
                                    InboundCard(inbound: inbound,
                                                onlineCount: onlineCount(for: inbound))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(ScreenBackground())
            .scrollContentBackground(.hidden)
            .navigationTitle("inbounds.title".loc)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    RefreshButton(isLoading: store.isLoading) {
                        Task { await store.refreshAll() }
                    }
                }
            }
            .navigationDestination(for: Int.self) { id in
                if let inbound = store.inbound(withId: id) {
                    InboundDetailView(inboundId: inbound.id)
                }
            }
            .refreshable { await store.refreshAll() }
        }
    }

    private func onlineCount(for inbound: Inbound) -> Int {
        inbound.clients.filter { store.onlineEmails.contains($0.email) }.count
    }
}

struct InboundCard: View {
    let inbound: Inbound
    let onlineCount: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            StatusDot(color: inbound.enable ? Theme.online : Theme.offline)
                            Text(inbound.remark.isEmpty ? inbound.tag : inbound.remark)
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Text("inbounds.port".loc(Fmt.digits(String(inbound.port))))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    protocolBadge
                }

                HStack(spacing: 10) {
                    pill(systemImage: "person.2.fill",
                         text: Fmt.digits("inbounds.clients_count".loc(inbound.clients.count)))
                    pill(systemImage: "dot.radiowaves.left.and.right",
                         text: Fmt.count(onlineCount), tint: Theme.online)
                }

                HStack(spacing: 16) {
                    trafficLabel("arrow.up", Fmt.bytes(inbound.up), Theme.accentIndigo)
                    trafficLabel("arrow.down", Fmt.bytes(inbound.down), Theme.accentCyan)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private var protocolBadge: some View {
        Text(inbound.`protocol`.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(Theme.accentGradient, in: Capsule())
    }

    private func pill(systemImage: String, text: String, tint: Color = Theme.textSecondary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).font(.caption2)
            Text(text).font(.caption.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.white.opacity(0.05), in: Capsule())
    }

    private func trafficLabel(_ symbol: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2).foregroundStyle(tint)
            Text(value).font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview {
    InboundsView()
        .environment(AppState.preview())
        .preferredColorScheme(.dark)
}
