import SwiftUI

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let border: Bool

    func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                border
                ? RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                : nil
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.regularMaterial)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionTitle: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.5))
            VStack(spacing: 6) {
                Text(title).font(.headline).multilineTextAlignment(.center)
                Text(subtitle).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            if let action, !actionTitle.isEmpty {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var iconColor: Color = .appPrimary
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 18, weight: .semibold))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title).font(.caption).foregroundColor(.secondary)

            if let sub = subtitle {
                Text(sub).font(.caption2).foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    var icon: String? = nil
    let title: String
    let isSelected: Bool
    var color: Color = .appPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.caption2) }
                Text(title).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: expense.category.icon)
                    .foregroundColor(expense.category.color)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.body).fontWeight(.medium).lineLimit(1)

                HStack(spacing: 6) {
                    Text(expense.date.relativeFormatted)
                        .font(.caption).foregroundColor(.secondary)
                    if !expense.merchant.isEmpty {
                        Text("• \(expense.merchant)")
                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.amount.formattedAsCurrency)
                    .font(.system(size: 15, weight: .semibold))
                    .minimumScaleFactor(0.8)
                if expense.isRecurring {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Amount Text

struct AmountText: View {
    let amount: Double
    let currency: String
    var fontSize: CGFloat = 17
    var fontWeight: Font.Weight = .semibold
    var color: Color = .primary

    var body: some View {
        Text(amount.formattedAsCurrency)
            .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
            .foregroundColor(color)
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: ExpenseCategory
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon).font(.caption)
            if showLabel { Text(category.displayName).font(.caption).fontWeight(.medium) }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(category.color.opacity(0.15))
        .foregroundColor(category.color)
        .clipShape(Capsule())
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
