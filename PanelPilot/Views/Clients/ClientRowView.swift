import SwiftUI

/// A single client row with a traffic ring, status dot, and metadata.
/// Swipe actions are attached by the parent list.
struct ClientRowView: View {
    let row: ClientRow
    var showInbound: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(fraction: row.trafficFraction, size: 46, lineWidth: 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    StatusDot(color: row.statusColor)
                    Text(row.client.email.isEmpty ? row.client.id : row.client.email)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if row.isOnline && row.client.enable {
                        Text("client.online_badge".loc)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.online)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.online.opacity(0.15), in: Capsule())
                    }
                }

                Text(Fmt.trafficUsage(used: row.used, limit: row.limit))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(Fmt.expiryLabel(expiryMs: row.client.expiryTime),
                          systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(expiryTint)
                    if showInbound {
                        Text("· \(row.inbound.remark.isEmpty ? row.inbound.tag : row.inbound.remark)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(.ultraThinMaterial)
        .background(Theme.backgroundElevated.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Theme.cardStroke, lineWidth: 1))
        .opacity(row.client.enable ? 1 : 0.55)
    }

    private var expiryTint: Color {
        if row.isExpired { return Theme.expired }
        if row.isExpiringSoon { return Theme.warning }
        return Theme.textSecondary
    }
}
