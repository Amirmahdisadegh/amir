import SwiftUI
import Foundation

// MARK: - Double Formatting

extension Double {
    var formattedAsCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        let number = formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
        let suffix = AppSettings.shared.isEnglish ? " T" : " تومان"
        return number + suffix
    }

    var formattedCompact: String {
        if self >= 1_000_000_000 { return String(format: "%.1fB", self / 1_000_000_000) }
        if self >= 1_000_000     { return String(format: "%.1fM", self / 1_000_000) }
        if self >= 1_000         { return String(format: "%.0fK", self / 1_000) }
        return String(format: "%.0f", self)
    }

    var formattedFull: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }
}

// MARK: - Date Formatting

extension Date {
    var shortFormatted: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }

    var relativeFormatted: String {
        let s = AppSettings.shared
        if Calendar.current.isDateInToday(self) { return s.t("Today", "امروز") }
        if Calendar.current.isDateInYesterday(self) { return s.t("Yesterday", "دیروز") }
        let f = DateFormatter()
        f.locale = Locale(identifier: s.language == "fa" ? "fa_IR" : "en_US")
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }

    var monthYearFormatted: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: self)
    }

    var farsiFormatted: String {
        let lang = AppSettings.shared.language
        let f = DateFormatter()
        f.locale = Locale(identifier: lang == "fa" ? "fa_IR" : "en_US")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }

    var farsiShort: String {
        let lang = AppSettings.shared.language
        let f = DateFormatter()
        f.locale = Locale(identifier: lang == "fa" ? "fa_IR" : "en_US")
        f.dateFormat = "d MMM"
        return f.string(from: self)
    }
}

// MARK: - Color Helpers

extension Color {
    static var appPrimary: Color { AppSettings.shared.theme.primary }
    static var cardBg: Color { Color(.secondarySystemBackground) }
    static var glassWhite: Color { Color.white.opacity(0.12) }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var border: Bool = true

    func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                border ?
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                : nil
            )
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func glassCard(cornerRadius: CGFloat = 20, border: Bool = true) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, border: border))
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionTitle: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.secondary.opacity(0.5))
            VStack(spacing: 6) {
                Text(title).font(.headline).multilineTextAlignment(.center)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if let action, !actionTitle.isEmpty {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appPrimary)
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
                .foregroundStyle(iconColor)
                .font(.system(size: 18, weight: .semibold))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(title).font(.caption).foregroundStyle(.secondary)

            if let sub = subtitle {
                Text(sub).font(.caption2).foregroundStyle(.secondary)
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
            .foregroundStyle(isSelected ? .white : .primary)
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
                    .foregroundStyle(expense.category.color)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.body).fontWeight(.medium).lineLimit(1)
                HStack(spacing: 6) {
                    Text(expense.date.relativeFormatted)
                        .font(.caption).foregroundStyle(.secondary)
                    if !expense.merchant.isEmpty {
                        Text("· \(expense.merchant)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
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
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Amount Text

struct AmountText: View {
    let amount: Double
    var fontSize: CGFloat = 17
    var fontWeight: Font.Weight = .semibold
    var color: Color = .primary

    var body: some View {
        Text(amount.formattedAsCurrency)
            .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
            .foregroundStyle(color)
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: ExpenseCategory
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon).font(.caption)
            if showLabel {
                Text(category.displayName).font(.caption).fontWeight(.medium)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(category.color.opacity(0.15))
        .foregroundStyle(category.color)
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
