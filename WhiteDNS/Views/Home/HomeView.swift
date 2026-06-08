import SwiftUI

struct HomeView: View {
    @EnvironmentObject var dns: DNSManager
    @State private var pulseAnimation = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    Spacer()
                    statusLabel
                    Spacer().frame(height: 48)
                    powerButton
                    Spacer().frame(height: 40)
                    providerCard
                    Spacer()
                    bottomHint
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("White DNS")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await dns.refreshStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.callout)
                    }
                }
            }
        }
    }

    // MARK: Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: dns.isConnected
                ? [Color(hex: "E8FDF5") ?? .green.opacity(0.1), Color(.systemBackground)]
                : [Color(.systemBackground), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: dns.isConnected)
    }

    // MARK: Status

    private var statusLabel: some View {
        HStack(spacing: 8) {
            ZStack {
                if dns.isConnected {
                    Circle()
                        .fill(Color.green.opacity(0.25))
                        .frame(width: 22, height: 22)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulseAnimation)
                }
                Circle()
                    .fill(dns.isConnected ? Color.green : Color(.systemGray3))
                    .frame(width: 12, height: 12)
            }

            Text(dns.isConnected ? "متصل" : "غیر فعال")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(dns.isConnected ? .green : .secondary)
        }
        .onAppear { pulseAnimation = true }
        .onChange(of: dns.isConnected) { _, connected in
            pulseAnimation = connected
        }
    }

    // MARK: Power Button

    private var powerButton: some View {
        Button {
            handleToggle()
        } label: {
            ZStack {
                // Outer glow ring when connected
                if dns.isConnected {
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.green.opacity(0.4), .teal.opacity(0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 3
                        )
                        .frame(width: 188, height: 188)
                }

                // Main circle
                Circle()
                    .fill(
                        dns.isConnected
                            ? LinearGradient(colors: [Color(hex: "34D399") ?? .green, Color(hex: "0D9488") ?? .teal],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray4)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 172, height: 172)
                    .shadow(
                        color: dns.isConnected ? Color.green.opacity(0.45) : Color.black.opacity(0.08),
                        radius: dns.isConnected ? 28 : 10,
                        y: dns.isConnected ? 10 : 5
                    )

                // Power icon
                Image(systemName: "power")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white)

                // Loading spinner
                if dns.isLoading {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 186, height: 186)
                        .rotationEffect(.degrees(dns.isLoading ? 360 : 0))
                        .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: dns.isLoading)
                }
            }
        }
        .disabled(dns.isLoading || (!dns.isConnected && dns.selectedProvider == nil))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: dns.isConnected)
        .scaleEffect(dns.isLoading ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: dns.isLoading)
    }

    // MARK: Provider Card

    @ViewBuilder
    private var providerCard: some View {
        if let provider = dns.selectedProvider {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(provider.color)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: iconFor(provider))
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .medium))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                    HStack(spacing: 6) {
                        ForEach(provider.servers, id: \.self) { s in
                            Text(s)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if s != provider.servers.last {
                                Text("·").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Text(provider.protocolType.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(provider.color.opacity(0.15))
                    .foregroundStyle(provider.color)
                    .clipShape(Capsule())
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            Text("برای شروع، یک سرور DNS انتخاب کنید")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
    }

    // MARK: Bottom Hint

    @ViewBuilder
    private var bottomHint: some View {
        if let error = dns.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.bottom, 16)
        } else {
            Text(dns.isConnected ? "ضربه بزنید تا قطع شود" : "ضربه بزنید تا متصل شوید")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
    }

    // MARK: Helpers

    private func handleToggle() {
        Task {
            if dns.isConnected {
                await dns.disconnect()
            } else if let provider = dns.selectedProvider {
                await dns.connect(provider: provider)
            }
        }
    }

    private func iconFor(_ provider: DNSProvider) -> String {
        switch provider.name {
        case "Cloudflare": return "bolt.fill"
        case "Google": return "magnifyingglass"
        case "Quad9": return "shield.fill"
        case "AdGuard": return "hand.raised.fill"
        case "Shecan": return "flag.fill"
        case "403.online": return "lock.open.fill"
        case "Electro": return "bolt.circle.fill"
        case "NextDNS": return "arrow.triangle.2.circlepath"
        default: return "server.rack"
        }
    }
}
