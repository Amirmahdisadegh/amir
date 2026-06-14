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
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(Theme.Font.title(17))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .monospacedDigit()
                Text(label)
                    .font(Theme.Font.caption(11))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
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
