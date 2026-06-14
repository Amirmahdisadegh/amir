import SwiftUI
import UIKit
import SwiftData

struct FoodDetailView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var entry: FoodEntry

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.md) {
                    if let data = entry.imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    }

                    macrosSummary

                    VStack(spacing: 10) {
                        ForEach(entry.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(Theme.Font.title(16))
                                        .foregroundStyle(Theme.textPrimary(scheme))
                                    Text(item.quantity)
                                        .font(Theme.Font.caption(12))
                                        .foregroundStyle(Theme.textSecondary(scheme))
                                }
                                Spacer()
                                Text("\(item.calories) kcal")
                                    .font(Theme.Font.title(15))
                                    .foregroundStyle(Theme.Palette.calorie)
                                    .monospacedDigit()
                            }
                            if item.id != entry.items.last?.id {
                                Divider().background(Theme.separator(scheme))
                            }
                        }
                    }
                    .cardSurface()
                }
                .padding(Theme.Space.md)
            }
            .background(AuroraBackground())
            .navigationTitle(entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("action.done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        context.delete(entry); try? context.save(); dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private var macrosSummary: some View {
        HStack {
            stat("\(entry.calories.grouped)", "kcal", Theme.Palette.calorie)
            Divider().frame(height: 36)
            stat("\(Int(entry.proteinGrams))g", "macro.protein", Theme.Palette.protein)
            stat("\(Int(entry.carbsGrams))g", "macro.carbs", Theme.Palette.carbs)
            stat("\(Int(entry.fatGrams))g", "macro.fat", Theme.Palette.fat)
        }
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private func stat(_ value: String, _ label: LocalizedStringKey, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.Font.title(18))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(Theme.Font.caption(11))
                .foregroundStyle(Theme.textSecondary(scheme))
        }
        .frame(maxWidth: .infinity)
    }
}
