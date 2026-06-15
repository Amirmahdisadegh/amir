import SwiftUI
import SwiftData

/// Search a built-in food list (and your recent foods) and log items without a photo.
struct FoodSearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]

    @State private var query = ""
    @State private var meal: MealType = .suggested()
    @State private var justAdded: String?

    private var results: [CommonFood] { FoodDatabase.search(query) }

    /// Up to 8 distinct recently-logged items.
    private var recents: [FoodItem] {
        var seen = Set<String>()
        var out: [FoodItem] = []
        for entry in entries {
            for item in entry.items where !item.name.isEmpty {
                let key = item.name.lowercased()
                if seen.insert(key).inserted { out.append(item) }
                if out.count >= 8 { return out }
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    mealPicker
                    searchField

                    if query.isEmpty && !recents.isEmpty {
                        sectionTitle("search.recent")
                        ForEach(recents) { item in
                            row(name: item.name, detail: item.quantity, kcal: item.calories) {
                                add(item: item)
                            }
                        }
                    }

                    sectionTitle("search.common")
                    ForEach(results) { food in
                        row(name: food.name, detail: food.serving, kcal: food.calories) {
                            add(item: food.asItem())
                        }
                    }
                    Color.clear.frame(height: 30)
                }
                .padding(Theme.Space.md)
            }
            .background(AuroraBackground())
            .navigationTitle("search.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }.bold()
                }
            }
        }
    }

    private var mealPicker: some View {
        HStack(spacing: 8) {
            ForEach(MealType.allCases) { m in
                let selected = meal == m
                Button { Haptics.tap(); meal = m } label: {
                    Text(LocalizedStringKey(m.titleKey))
                        .font(Theme.Font.caption(12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(selected ? .white : Theme.textSecondary(scheme))
                        .background(Capsule().fill(selected ? AnyShapeStyle(Theme.energyGradient)
                                                            : AnyShapeStyle(Theme.chipFill(scheme))))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary(scheme))
            TextField("search.placeholder", text: $query)
                .font(Theme.Font.body(15))
                .foregroundStyle(Theme.textPrimary(scheme))
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(Theme.chipFill(scheme),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Theme.Font.caption(13))
            .foregroundStyle(Theme.textSecondary(scheme))
            .padding(.top, 4)
    }

    private func row(name: String, detail: String, kcal: Int, add: @escaping () -> Void) -> some View {
        Button(action: add) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Theme.Font.title(15))
                        .foregroundStyle(Theme.textPrimary(scheme))
                    Text(detail)
                        .font(Theme.Font.caption(12))
                        .foregroundStyle(Theme.textSecondary(scheme))
                }
                Spacer()
                if justAdded == name {
                    Label("search.added", systemImage: "checkmark.circle.fill")
                        .font(Theme.Font.caption(12))
                        .foregroundStyle(Theme.Palette.success)
                } else {
                    Text("\(kcal) kcal")
                        .font(Theme.Font.title(14))
                        .foregroundStyle(Theme.Palette.calorie)
                        .monospacedDigit()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.Palette.brand)
                }
            }
            .cardSurface(padding: 12, radius: Theme.Radius.md)
        }
        .buttonStyle(.plain)
    }

    private func add(item: FoodItem) {
        let entry = FoodEntry(title: item.name, meal: meal, items: [item])
        context.insert(entry)
        try? context.save()
        Haptics.success()
        withAnimation { justAdded = item.name }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if justAdded == item.name { withAnimation { justAdded = nil } }
        }
    }
}
