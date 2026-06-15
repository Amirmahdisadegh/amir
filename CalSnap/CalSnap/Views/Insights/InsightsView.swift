import SwiftUI
import SwiftData
import Charts

struct DayBucket: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Int
}

struct InsightsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @Query(sort: \WeightEntry.date, order: .forward) private var weights: [WeightEntry]

    /// Calories per day for the last 7 days, oldest first.
    private var week: [DayBucket] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: .now)!.startOfDay
            let cals = entries
                .filter { $0.date.isSameDay(as: day) }
                .reduce(0) { $0 + $1.calories }
            return DayBucket(date: day, calories: cals)
        }
    }

    private var weekAverage: Int {
        let logged = week.filter { $0.calories > 0 }
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.calories } / logged.count
    }

    private var goal: Int { appState.profile.calorieGoal }

    // Macro split across the whole week.
    private var macroTotals: (p: Int, c: Int, f: Int) {
        let last7 = entries.filter {
            guard let d = Calendar.current.date(byAdding: .day, value: -7, to: .now) else { return false }
            return $0.date >= d
        }
        return (
            Int(last7.reduce(0) { $0 + $1.proteinGrams }),
            Int(last7.reduce(0) { $0 + $1.carbsGrams }),
            Int(last7.reduce(0) { $0 + $1.fatGrams })
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("insights.title")
                    .font(Theme.Font.display(28))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .padding(.top, 8)

                summaryRow
                statsRow
                weeklyChartCard
                weightCard
                macroCard
                projectionCard
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, Theme.Space.md)
        }
        .scrollIndicators(.hidden)
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            StatPill(icon: "chart.line.uptrend.xyaxis", label: "insights.avg",
                     value: weekAverage.grouped, tint: Theme.Palette.brand)
            StatPill(icon: "target", label: "stat.goal",
                     value: goal.grouped, tint: Theme.Palette.calorie)
        }
    }

    // MARK: Extra stats

    private var currentStreak: Int { Stats.currentStreak(entries) }
    private var bestStreak: Int { Stats.longestStreak(entries) }

    private var weekWaterAvg: Int {
        let cal = Calendar.current
        let vals = (0..<7).compactMap { offset -> Int? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            let w = appState.water(on: day)
            return w > 0 ? w : nil
        }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / vals.count
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatPill(icon: "flame.fill", label: "insights.streak",
                     value: "\(currentStreak)", tint: Theme.Palette.calorie)
            StatPill(icon: "trophy.fill", label: "insights.bestStreak",
                     value: "\(bestStreak)", tint: Theme.Palette.carbs)
            StatPill(icon: "drop.fill", label: "insights.water",
                     value: "\(weekWaterAvg)", tint: Theme.Palette.protein)
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader("insights.weight")
            if weights.count >= 2 {
                Chart(weights, id: \.id) { e in
                    LineMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Theme.Palette.brand)
                    PointMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                        .foregroundStyle(Theme.Palette.brand)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
            } else {
                Text("insights.noWeight")
                    .font(Theme.Font.body(13))
                    .foregroundStyle(Theme.textSecondary(scheme))
                    .padding(.vertical, 20)
            }
        }
        .cardSurface()
    }

    private var projectionCard: some View {
        // ~7700 kcal per kg of body weight.
        let perWeek = Double(appState.profile.goal.calorieDelta * 7) / 7700.0
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("insights.projection")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%+.2f kg", perWeek))
                    .font(Theme.Font.display(26))
                    .foregroundStyle(perWeek <= 0 ? Theme.Palette.success : Theme.Palette.calorie)
                Text("insights.perWeek")
                    .font(Theme.Font.caption(13))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
            Text(LocalizedStringKey(appState.profile.goal.titleKey))
                .font(Theme.Font.caption(12))
                .foregroundStyle(Theme.textSecondary(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader("insights.last7")
            Chart {
                ForEach(week) { bucket in
                    BarMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Calories", bucket.calories)
                    )
                    .foregroundStyle(bucket.calories > goal
                                     ? Theme.Palette.calorie : Theme.Palette.brand)
                    .cornerRadius(6)
                }
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Theme.textSecondary(scheme).opacity(0.6))
                    .annotation(position: .top, alignment: .leading) {
                        Text("insights.goalLine")
                            .font(Theme.Font.caption(10))
                            .foregroundStyle(Theme.textSecondary(scheme))
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 200)
        }
        .cardSurface()
    }

    private var macroCard: some View {
        let m = macroTotals
        let total = max(m.p + m.c + m.f, 1)
        return VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader("insights.macroSplit")
            Chart {
                SectorMark(angle: .value("P", m.p), innerRadius: .ratio(0.6), angularInset: 2)
                    .foregroundStyle(Theme.Palette.protein)
                    .cornerRadius(4)
                SectorMark(angle: .value("C", m.c), innerRadius: .ratio(0.6), angularInset: 2)
                    .foregroundStyle(Theme.Palette.carbs)
                    .cornerRadius(4)
                SectorMark(angle: .value("F", m.f), innerRadius: .ratio(0.6), angularInset: 2)
                    .foregroundStyle(Theme.Palette.fat)
                    .cornerRadius(4)
            }
            .frame(height: 170)

            HStack(spacing: 16) {
                legend("macro.protein", Theme.Palette.protein, m.p, total)
                legend("macro.carbs", Theme.Palette.carbs, m.c, total)
                legend("macro.fat", Theme.Palette.fat, m.f, total)
            }
        }
        .cardSurface()
    }

    private func legend(_ label: LocalizedStringKey, _ color: Color, _ value: Int, _ total: Int) -> some View {
        let pct = Int(Double(value) / Double(total) * 100)
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(Theme.Font.caption(11))
                    .foregroundStyle(Theme.textSecondary(scheme))
                Text("\(pct)%").font(Theme.Font.caption(13))
                    .foregroundStyle(Theme.textPrimary(scheme))
            }
        }
    }
}
