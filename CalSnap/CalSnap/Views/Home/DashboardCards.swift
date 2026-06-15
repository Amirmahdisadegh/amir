import SwiftUI
import SwiftData
import Charts

// MARK: - Water

struct WaterCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme

    private let water = Color(hex: 0x38BDF8)

    var body: some View {
        let current = appState.water()
        let goal = max(appState.waterGoalML, 1)
        let progress = min(Double(current) / Double(goal), 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("water.title", systemImage: "drop.fill")
                    .font(Theme.Font.title(16))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Spacer()
                Text("\(current) / \(goal) ml")
                    .font(Theme.Font.caption(13))
                    .foregroundStyle(water)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.separator(scheme))
                    Capsule()
                        .fill(LinearGradient(colors: [water.opacity(0.7), water],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 10)
            HStack(spacing: 8) {
                addButton("+250", 250)
                addButton("+500", 500)
                Spacer()
                Button {
                    Haptics.tap(); appState.addWater(-250)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary(scheme))
                        .frame(width: 38, height: 34)
                        .background(Theme.chipFill(scheme), in: Capsule())
                }
            }
        }
        .cardSurface()
    }

    private func addButton(_ label: String, _ ml: Int) -> some View {
        Button {
            Haptics.tap(); appState.addWater(ml)
        } label: {
            Text(label)
                .font(Theme.Font.title(14))
                .foregroundStyle(water)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(water.opacity(0.15), in: Capsule())
        }
    }
}

// MARK: - Weight

struct WeightCard: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \WeightEntry.date, order: .forward) private var weights: [WeightEntry]
    var onLog: () -> Void

    private var recent: [WeightEntry] { Array(weights.suffix(14)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("weight.title", systemImage: "scalemass.fill")
                    .font(Theme.Font.title(16))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Spacer()
                Button(action: { Haptics.tap(); onLog() }) {
                    Label("weight.log", systemImage: "plus")
                        .font(Theme.Font.caption(13))
                        .foregroundStyle(Theme.Palette.brand)
                }
            }

            if let latest = weights.last {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", latest.kg))
                        .font(Theme.Font.mono(30))
                        .foregroundStyle(Theme.textPrimary(scheme))
                    Text("kg").font(Theme.Font.caption(13))
                        .foregroundStyle(Theme.textSecondary(scheme))
                    if let delta = trendDelta {
                        Spacer()
                        Label(String(format: "%+.1f", delta), systemImage: delta <= 0 ? "arrow.down" : "arrow.up")
                            .font(Theme.Font.caption(12))
                            .foregroundStyle(delta <= 0 ? Theme.Palette.success : Theme.Palette.calorie)
                    }
                }
                if recent.count >= 2 {
                    Chart(recent, id: \.id) { e in
                        LineMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.Palette.brand)
                        AreaMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.energyGradient.opacity(0.15))
                    }
                    .chartXAxis(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 70)
                }
            } else {
                Text("weight.empty")
                    .font(Theme.Font.body(13))
                    .foregroundStyle(Theme.textSecondary(scheme))
                    .padding(.vertical, 6)
            }
        }
        .cardSurface()
    }

    private var trendDelta: Double? {
        guard let last = weights.last, weights.count >= 2 else { return nil }
        return last.kg - weights[weights.count - 2].kg
    }
}

// MARK: - Log weight sheet

struct WeightLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var kg: Double = 70

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            VStack(spacing: 6) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.Palette.brand)
                Text("weight.logTitle")
                    .font(Theme.Font.title(20))
                    .foregroundStyle(Theme.textPrimary(scheme))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("70", value: $kg, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.Font.mono(40))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .frame(width: 150)
                Text("kg").font(Theme.Font.caption(14))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
            Slider(value: $kg, in: 30...250, step: 0.1).tint(Theme.Palette.brand)
            Button("action.save") { save() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.Space.lg)
        .frame(maxHeight: .infinity)
        .background(AuroraBackground())
        .onAppear { kg = appState.profile.weightKg }
    }

    private func save() {
        context.insert(WeightEntry(kg: kg))
        var p = appState.profile
        p.weightKg = kg
        appState.profile = p
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
