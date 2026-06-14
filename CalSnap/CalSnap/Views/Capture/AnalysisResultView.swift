import SwiftUI
import UIKit

struct AnalysisResultView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: CaptureViewModel
    var onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("result.title")
                    .font(Theme.Font.display(24))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Spacer()
                CloseButton { dismiss() }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: Theme.Space.md) {
                    heroCard
                    if vm.isEstimateOnly { estimateBanner }
                    mealPicker
                    itemsCard
                    addItemButton
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.md)
            }
            .scrollIndicators(.hidden)

            // Sticky save bar
            saveBar
        }
        .background(Theme.background(scheme).ignoresSafeArea())
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(spacing: 14) {
            if let image = vm.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            }
            TextField("result.mealName", text: $vm.title)
                .font(Theme.Font.title(20))
                .foregroundStyle(Theme.textPrimary(scheme))
                .multilineTextAlignment(.center)

            if !vm.summary.isEmpty {
                Text(vm.summary)
                    .font(Theme.Font.body(13))
                    .foregroundStyle(Theme.textSecondary(scheme))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 18) {
                totalStat("\(vm.totalCalories.grouped)", "kcal", Theme.Palette.calorie)
                Divider().frame(height: 28)
                totalStat("\(Int(vm.totalProtein))g", "macro.protein", Theme.Palette.protein)
                totalStat("\(Int(vm.totalCarbs))g", "macro.carbs", Theme.Palette.carbs)
                totalStat("\(Int(vm.totalFat))g", "macro.fat", Theme.Palette.fat)
            }
        }
        .cardSurface()
    }

    private func totalStat(_ value: String, _ label: LocalizedStringKey, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Font.title(17))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(Theme.Font.caption(10))
                .foregroundStyle(Theme.textSecondary(scheme))
        }
    }

    private var estimateBanner: some View {
        Label("result.estimateBanner", systemImage: "wifi.slash")
            .font(Theme.Font.caption(12))
            .foregroundStyle(Theme.Palette.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.Palette.warning.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    // MARK: Meal picker

    private var mealPicker: some View {
        HStack(spacing: 8) {
            ForEach(MealType.allCases) { meal in
                let selected = vm.meal == meal
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3)) { vm.meal = meal }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: meal.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(LocalizedStringKey(meal.titleKey))
                            .font(Theme.Font.caption(11))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selected ? .white : Theme.textSecondary(scheme))
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(selected ? AnyShapeStyle(Theme.energyGradient)
                                           : AnyShapeStyle(Theme.surface(scheme)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.separator(scheme), lineWidth: selected ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Items

    private var itemsCard: some View {
        VStack(spacing: 10) {
            ForEach($vm.items) { $item in
                FoodItemEditor(item: $item) {
                    withAnimation { vm.items.removeAll { $0.id == item.id } }
                }
                if item.id != vm.items.last?.id {
                    Divider().background(Theme.separator(scheme))
                }
            }
            if vm.items.isEmpty {
                Text("result.noItems")
                    .font(Theme.Font.body(13))
                    .foregroundStyle(Theme.textSecondary(scheme))
                    .padding(.vertical, 12)
            }
        }
        .cardSurface()
    }

    private var addItemButton: some View {
        Button {
            Haptics.tap()
            withAnimation { vm.addBlankItem() }
        } label: {
            Label("result.addItem", systemImage: "plus.circle.fill")
                .font(Theme.Font.title(15))
                .foregroundStyle(Theme.Palette.brand)
        }
    }

    // MARK: Save bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.separator(scheme))
            Button {
                onSave()
            } label: {
                Label("result.save", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(Theme.Space.md)
        }
        .background(Theme.surface(scheme))
    }
}

// MARK: - Editable food item row

struct FoodItemEditor: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var item: FoodItem
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("item.name", text: $item.name)
                    .font(Theme.Font.title(16))
                    .foregroundStyle(Theme.textPrimary(scheme))
                Spacer()
                if item.confidence < 0.6 {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.warning)
                }
                Button(action: { Haptics.tap(); onDelete() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
            HStack(spacing: 8) {
                miniField("item.qty", text: $item.quantity, width: nil)
                Spacer()
                numberField("kcal", value: $item.calories, tint: Theme.Palette.calorie)
            }
            HStack(spacing: 8) {
                macroField("P", value: $item.proteinGrams, tint: Theme.Palette.protein)
                macroField("C", value: $item.carbsGrams, tint: Theme.Palette.carbs)
                macroField("F", value: $item.fatGrams, tint: Theme.Palette.fat)
            }
        }
        .padding(.vertical, 4)
    }

    private func miniField(_ placeholder: LocalizedStringKey, text: Binding<String>, width: CGFloat?) -> some View {
        TextField(placeholder, text: text)
            .font(Theme.Font.caption(13))
            .foregroundStyle(Theme.textSecondary(scheme))
            .frame(width: width)
    }

    private func numberField(_ unit: String, value: Binding<Int>, tint: Color) -> some View {
        HStack(spacing: 3) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.Font.title(15))
                .foregroundStyle(tint)
                .frame(width: 56)
                .monospacedDigit()
            Text(unit)
                .font(Theme.Font.caption(11))
                .foregroundStyle(Theme.textSecondary(scheme))
        }
    }

    private func macroField(_ label: String, value: Binding<Double>, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Theme.Font.caption(12))
                .foregroundStyle(tint)
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .font(Theme.Font.caption(13))
                .foregroundStyle(Theme.textPrimary(scheme))
                .frame(width: 42)
                .monospacedDigit()
            Text("g")
                .font(Theme.Font.caption(11))
                .foregroundStyle(Theme.textSecondary(scheme))
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(tint.opacity(0.1), in: Capsule())
    }
}
