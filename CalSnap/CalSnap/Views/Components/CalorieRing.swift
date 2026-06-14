import SwiftUI

/// A bold animated ring showing calories consumed vs. goal.
struct CalorieRing: View {
    @Environment(\.colorScheme) private var scheme
    var consumed: Int
    var goal: Int
    var burned: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1)
    }

    private var remaining: Int { max(goal + burned - consumed, 0) }
    private var over: Bool { consumed > goal + burned }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.separator(scheme), lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    over ? Theme.calorieGradient : Theme.energyGradient,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)

            VStack(spacing: 2) {
                Text("\(remaining.grouped)")
                    .font(Theme.Font.mono(40))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .contentTransition(.numericText())
                Text(over ? "label.over" : "label.remaining")
                    .font(Theme.Font.caption(13))
                    .foregroundStyle(Theme.textSecondary(scheme))
                Text("kcal")
                    .font(Theme.Font.caption(11))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
        }
    }
}

/// A compact macro progress bar (protein / carbs / fat).
struct MacroBar: View {
    @Environment(\.colorScheme) private var scheme
    var title: LocalizedStringKey
    var value: Int
    var goal: Int
    var color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(Theme.Font.caption(13))
                    .foregroundStyle(Theme.textSecondary(scheme))
                Spacer()
                Text("\(value)/\(goal)g")
                    .font(Theme.Font.caption(12))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.separator(scheme))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}
