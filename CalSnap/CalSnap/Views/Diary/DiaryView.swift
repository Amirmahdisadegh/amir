import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]

    @State private var selectedEntry: FoodEntry?

    /// Entries grouped by start-of-day, newest first.
    private var grouped: [(day: Date, items: [FoodEntry])] {
        let dict = Dictionary(grouping: entries) { $0.date.startOfDay }
        return dict.keys.sorted(by: >).map { ($0, dict[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("diary.title")
                    .font(Theme.Font.display(28))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .padding(.top, 8)

                if entries.isEmpty {
                    EmptyStateView(icon: "book.closed",
                                   title: "empty.diary.title",
                                   message: "empty.diary.message")
                        .cardSurface()
                } else {
                    ForEach(grouped, id: \.day) { group in
                        daySection(group.day, group.items)
                    }
                }
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, Theme.Space.md)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selectedEntry) { FoodDetailView(entry: $0) }
    }

    private func daySection(_ day: Date, _ items: [FoodEntry]) -> some View {
        let total = items.reduce(0) { $0 + $1.calories }
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Text(dayLabel(day))
                    .font(Theme.Font.title(17))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Spacer()
                Text("\(total.grouped) kcal")
                    .font(Theme.Font.caption(13))
                    .foregroundStyle(Theme.Palette.brand)
                    .monospacedDigit()
            }
            ForEach(items) { entry in
                Button { selectedEntry = entry } label: { MealRow(entry: entry) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { delete(entry) } label: {
                            Label("action.delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        if day.isSameDay(as: .now) { return String(localized: "date.today") }
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now),
           day.isSameDay(as: yesterday) { return String(localized: "date.yesterday") }
        return day.formatted(.dateTime.weekday(.wide).day().month())
    }

    private func delete(_ entry: FoodEntry) {
        withAnimation { context.delete(entry); try? context.save() }
    }
}
