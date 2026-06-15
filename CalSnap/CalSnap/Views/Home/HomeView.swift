import SwiftUI
import SwiftData

/// Sheets presented from Home (single sheet modifier to avoid conflicts).
enum HomeSheet: Identifiable {
    case meal(FoodEntry)
    case burned
    var id: String {
        switch self {
        case .meal(let e): return "meal-\(e.id.uuidString)"
        case .burned:      return "burned"
        }
    }
}

/// Aggregated nutrition for a set of entries.
struct DailyTotals {
    var calories = 0, protein = 0, carbs = 0, fat = 0
    init(_ entries: [FoodEntry]) {
        for e in entries {
            calories += e.calories
            protein += Int(e.proteinGrams.rounded())
            carbs += Int(e.carbsGrams.rounded())
            fat += Int(e.fatGrams.rounded())
        }
    }
}

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    @State private var sheet: HomeSheet?

    private var todayEntries: [FoodEntry] {
        allEntries.filter { $0.date.isSameDay(as: .now) }
    }
    private var totals: DailyTotals { DailyTotals(todayEntries) }
    private var profile: UserProfile { appState.profile }
    private var burned: Int { appState.burned() }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.lg) {
                header
                ringCard
                macrosCard
                mealsSection
                Color.clear.frame(height: 96) // tab bar spacing
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.sm)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $sheet) { which in
            switch which {
            case .meal(let entry):
                FoodDetailView(entry: entry)
            case .burned:
                BurnedEditorView().presentationDetents([.height(280)])
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(Theme.Font.caption(14))
                    .foregroundStyle(Theme.textSecondary(scheme))
                Text(profile.name.isEmpty ? "CalSnap" : profile.name)
                    .font(Theme.Font.display(28))
                    .foregroundStyle(Theme.textPrimary(scheme))
            }
            Spacer()
            Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                .font(Theme.Font.caption(13))
                .foregroundStyle(Theme.textSecondary(scheme))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.surface(scheme), in: Capsule())
        }
        .padding(.top, 8)
    }

    private var greeting: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12:  return "greeting.morning"
        case 12..<17: return "greeting.afternoon"
        case 17..<22: return "greeting.evening"
        default:      return "greeting.night"
        }
    }

    // MARK: Ring card

    private var ringCard: some View {
        VStack(spacing: Theme.Space.md) {
            CalorieRing(consumed: totals.calories,
                        goal: profile.calorieGoal,
                        burned: burned)
                .frame(height: 210)
                .padding(.vertical, 4)

            HStack(spacing: 10) {
                StatPill(icon: "fork.knife", label: "stat.eaten",
                         value: totals.calories.grouped, tint: Theme.Palette.calorie)
                Button {
                    Haptics.tap()
                    sheet = .burned
                } label: {
                    StatPill(icon: "flame.fill", label: "stat.burned",
                             value: burned.grouped, tint: Theme.Palette.warning)
                }
                .buttonStyle(.plain)
                StatPill(icon: "target", label: "stat.goal",
                         value: profile.calorieGoal.grouped, tint: Theme.Palette.brand)
            }
        }
        .cardSurface()
    }

    // MARK: Macros

    private var macrosCard: some View {
        VStack(spacing: 14) {
            MacroBar(title: "macro.protein", value: totals.protein,
                     goal: profile.proteinGoal, color: Theme.Palette.protein)
            MacroBar(title: "macro.carbs", value: totals.carbs,
                     goal: profile.carbsGoal, color: Theme.Palette.carbs)
            MacroBar(title: "macro.fat", value: totals.fat,
                     goal: profile.fatGoal, color: Theme.Palette.fat)
        }
        .cardSurface()
    }

    // MARK: Today's meals

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("home.todaysMeals")
            if todayEntries.isEmpty {
                EmptyStateView(icon: "camera.viewfinder",
                               title: "empty.today.title",
                               message: "empty.today.message")
                    .cardSurface()
            } else {
                ForEach(todayEntries) { entry in
                    Button { sheet = .meal(entry) } label: {
                        MealRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

/// A single meal row used in lists.
struct MealRow: View {
    @Environment(\.colorScheme) private var scheme
    var entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            MealThumbnail(imageData: entry.imageData, meal: entry.meal)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(Theme.Font.title(16))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: entry.meal.symbol)
                        .font(.system(size: 11))
                    Text(LocalizedStringKey(entry.meal.titleKey))
                    Text("·")
                    Text(entry.date, format: .dateTime.hour().minute())
                }
                .font(Theme.Font.caption(12))
                .foregroundStyle(Theme.textSecondary(scheme))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.calories.grouped)")
                    .font(Theme.Font.title(17))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .monospacedDigit()
                Text("kcal")
                    .font(Theme.Font.caption(10))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
        }
        .cardSurface(padding: 12, radius: Theme.Radius.md)
    }
}
