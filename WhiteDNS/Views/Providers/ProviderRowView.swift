import SwiftUI

struct ProviderRowView: View {
    @EnvironmentObject var dns: DNSManager
    let provider: DNSProvider

    var isSelected: Bool { dns.selectedProvider?.id == provider.id }

    var body: some View {
        HStack(spacing: 14) {
            // Icon tile
            RoundedRectangle(cornerRadius: 10)
                .fill(provider.color.gradient)
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: iconFor(provider))
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .medium))
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Text(provider.name)
                        .font(.headline)

                    if provider.isCustom {
                        Text("سفارشی")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(provider.protocolType.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }

                Text(provider.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    ForEach(provider.servers, id: \.self) { server in
                        Text(server)
                            .font(.caption2)
                            .foregroundStyle(Color(.tertiaryLabel))
                        if server != provider.servers.last {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                }
            }

            // Selection indicator
            if isSelected {
                Image(systemName: dns.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(dns.isConnected ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
