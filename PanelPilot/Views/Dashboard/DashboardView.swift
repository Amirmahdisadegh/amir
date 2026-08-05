import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(AppState.self) private var app
    private var store: DataStore { app.store }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.inbounds.isEmpty && store.serverStatus == nil && store.isLoading {
                        SkeletonList(count: 4).padding(.top, 8)
                    } else if let error = store.error, store.serverStatus == nil {
                        ErrorStateView(error: error) { Task { await store.refreshAll() } }
                    } else {
                        aggregateGrid
                        clientHealthCard
                        if let status = store.serverStatus {
                            systemCard(status)
                            networkCard(status)
                        }
                        trafficChart
                    }
                    lastUpdatedFooter
                }
                .padding()
            }
            .background(ScreenBackground())
            .scrollContentBackground(.hidden)
            .navigationTitle("dashboard.title".loc)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    RefreshButton(isLoading: store.isLoading) {
                        Task { await store.refreshAll() }
                    }
                }
            }
            .refreshable { await store.refreshAll() }
        }
    }

    // MARK: - Aggregate stats

    private var aggregateGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(title: "dashboard.total_clients".loc,
                     value: Fmt.count(store.totalClients),
                     systemImage: "person.3.fill", tint: Theme.accentIndigo)
            StatTile(title: "dashboard.online_now".loc,
                     value: Fmt.count(store.onlineCount),
                     systemImage: "dot.radiowaves.left.and.right", tint: Theme.online)
            StatTile(title: "dashboard.inbounds_count".loc,
                     value: Fmt.count(store.inbounds.count),
                     systemImage: "arrow.down.left.arrow.up.right", tint: Theme.accentCyan)
            StatTile(title: "dashboard.total_traffic".loc,
                     value: Fmt.bytes(store.totalTraffic),
                     systemImage: "chart.bar.fill", tint: Theme.warning)
        }
    }

    // MARK: - Client health

    private var clientHealthCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                SectionHeader(title: "dashboard.client_health".loc, symbol: "heart.text.square.fill")
                HStack(spacing: 10) {
                    healthPill(count: store.expiringSoonCount, title: "clients.filter.expiring".loc,
                               symbol: "hourglass", tint: Theme.warning)
                    healthPill(count: store.overLimitCount, title: "clients.filter.over80".loc,
                               symbol: "gauge.high", tint: Theme.accentCyan)
                    healthPill(count: store.expiredCount, title: "client.expired".loc,
                               symbol: "xmark.circle", tint: Theme.expired)
                    healthPill(count: store.disabledCount, title: "clients.filter.disabled".loc,
                               symbol: "pause.circle", tint: Theme.offline)
                }
            }
        }
    }

    private func healthPill(count: Int, title: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint)
            Text(Fmt.count(count)).font(.title3.weight(.bold)).foregroundStyle(Theme.textPrimary)
            Text(title).font(.caption2).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - System card

    private func systemCard(_ status: ServerStatus) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    SectionHeader(title: "dashboard.system".loc, symbol: "cpu.fill")
                    xrayBadge(status)
                }
                HStack(spacing: 14) {
                    gauge(title: "dashboard.cpu".loc, fraction: status.cpu / 100,
                          label: Fmt.percent(status.cpu / 100))
                    gauge(title: "dashboard.memory".loc, fraction: status.memFraction,
                          label: Fmt.percent(status.memFraction))
                    gauge(title: "dashboard.disk".loc, fraction: status.diskFraction,
                          label: Fmt.percent(status.diskFraction))
                }
                HStack {
                    metric("dashboard.uptime".loc, Fmt.uptime(status.uptime), "clock.fill")
                    Spacer()
                    metric("dashboard.connections".loc,
                           Fmt.count(status.tcpCount + status.udpCount), "network")
                }
            }
        }
    }

    private func gauge(title: String, fraction: Double, label: String) -> some View {
        VStack(spacing: 8) {
            ProgressRing(fraction: fraction, size: 62, lineWidth: 7, showLabel: false)
                .overlay(
                    Text(label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                )
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Theme.accentCyan).font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Text(title).font(.caption2).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func xrayBadge(_ status: ServerStatus) -> some View {
        HStack(spacing: 6) {
            StatusDot(color: status.xrayRunning ? Theme.online : Theme.expired)
            Text(status.xrayRunning ? "dashboard.running".loc : "dashboard.stopped".loc)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            if !status.xrayVersion.isEmpty {
                Text(Fmt.digits("v\(status.xrayVersion)"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accentCyan)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.accentCyan.opacity(0.12), in: Capsule())
            }
        }
    }

    // MARK: - Network card

    private func networkCard(_ status: ServerStatus) -> some View {
        GlassCard {
            VStack(spacing: 14) {
                SectionHeader(title: "dashboard.speed".loc, symbol: "speedometer")
                HStack(spacing: 12) {
                    speedTile("dashboard.upload".loc, Fmt.speed(status.netUp),
                              "arrow.up.circle.fill", Theme.accentIndigo)
                    speedTile("dashboard.download".loc, Fmt.speed(status.netDown),
                              "arrow.down.circle.fill", Theme.accentCyan)
                }
            }
        }
    }

    private func speedTile(_ title: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.title2).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline).foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Traffic chart

    private var trafficChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "dashboard.traffic_chart".loc, symbol: "chart.xyaxis.line")
                if store.trafficSamples.count < 2 {
                    Text("dashboard.no_samples".loc)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Chart {
                        ForEach(Array(store.trafficSamples.enumerated()), id: \.offset) { _, s in
                            AreaMark(
                                x: .value("t", s.date),
                                y: .value("down", Double(s.down) / 1_000_000)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.accentCyan.opacity(0.5), .clear],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("t", s.date),
                                y: .value("down", Double(s.down) / 1_000_000),
                                series: .value("s", "down")
                            )
                            .foregroundStyle(Theme.accentCyan)
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("t", s.date),
                                y: .value("up", Double(s.up) / 1_000_000),
                                series: .value("s", "up")
                            )
                            .foregroundStyle(Theme.accentIndigo)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(Fmt.digits(String(format: "%.0f MB/s", v)))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 150)
                    HStack(spacing: 16) {
                        legendDot(Theme.accentCyan, "dashboard.download".loc)
                        legendDot(Theme.accentIndigo, "dashboard.upload".loc)
                    }
                }
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    private var lastUpdatedFooter: some View {
        Group {
            if let updated = store.lastUpdated {
                Text("common.updated".loc(Fmt.relative(updated)))
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState.preview())
        .preferredColorScheme(.dark)
}
