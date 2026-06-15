import SwiftUI
import UIKit

/// Section header with an optional trailing accessory.
struct SectionHeader<Trailing: View>: View {
    @Environment(\.colorScheme) private var scheme
    var title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Font.title(20))
                .foregroundStyle(Theme.textPrimary(scheme))
            Spacer()
            trailing
        }
    }
}

/// Small stat chip used in the dashboard hero (e.g. burned, eaten).
struct StatPill: View {
    @Environment(\.colorScheme) private var scheme
    var icon: String
    var label: LocalizedStringKey
    var value: String
    var tint: Color

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(Theme.Font.title(16))
                .foregroundStyle(Theme.textPrimary(scheme))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Theme.Font.caption(10))
                .foregroundStyle(Theme.textSecondary(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.chipFill(scheme),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.glassBorder(scheme), lineWidth: 1)
        )
    }
}

/// Friendly empty-state placeholder.
struct EmptyStateView: View {
    @Environment(\.colorScheme) private var scheme
    var icon: String
    var title: LocalizedStringKey
    var message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.Palette.brand.opacity(0.8))
            Text(title)
                .font(Theme.Font.title(18))
                .foregroundStyle(Theme.textPrimary(scheme))
            Text(message)
                .font(Theme.Font.body(14))
                .foregroundStyle(Theme.textSecondary(scheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Meal thumbnail with graceful fallback to a meal icon.
struct MealThumbnail: View {
    @Environment(\.colorScheme) private var scheme
    var imageData: Data?
    var meal: MealType
    var size: CGFloat = 54

    var body: some View {
        Group {
            if let imageData, let ui = UIImage(data: imageData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.energyGradient.opacity(0.18)
                    Image(systemName: meal.symbol)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(Theme.Palette.brand)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}
