import SwiftUI

struct ProfileEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = UserProfile()
    @State private var useManualGoal = false
    @State private var manualGoal = 2000

    var body: some View {
        NavigationStack {
            Form {
                Section("profile.basics") {
                    TextField("profile.name", text: $draft.name)
                    Picker("profile.sex", selection: $draft.sex) {
                        ForEach(Sex.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
                    }
                    Stepper("profile.age \(draft.age)", value: $draft.age, in: 10...100)
                }

                Section("profile.body") {
                    sliderRow("profile.height", value: $draft.heightCm, range: 120...220, unit: "cm")
                    sliderRow("profile.weight", value: $draft.weightKg, range: 35...200, unit: "kg")
                }

                Section("profile.activity") {
                    Picker("profile.activityLevel", selection: $draft.activity) {
                        ForEach(ActivityLevel.allCases) {
                            Text(LocalizedStringKey($0.titleKey)).tag($0)
                        }
                    }
                    Picker("profile.goal", selection: $draft.goal) {
                        ForEach(GoalDirection.allCases) {
                            Text(LocalizedStringKey($0.titleKey)).tag($0)
                        }
                    }
                }

                Section {
                    Toggle("profile.manualGoal", isOn: $useManualGoal)
                    if useManualGoal {
                        Stepper("profile.calorieTarget \(manualGoal)",
                                value: $manualGoal, in: 1000...5000, step: 50)
                    }
                } footer: {
                    Text("profile.computedGoal \(computedGoal)")
                }
            }
            .navigationTitle("settings.profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") { save() }.bold()
                }
            }
            .onAppear {
                draft = appState.profile
                if let manual = draft.manualCalorieGoal {
                    useManualGoal = true
                    manualGoal = manual
                }
            }
        }
    }

    private var computedGoal: Int {
        var copy = draft
        copy.manualCalorieGoal = nil
        return copy.calorieGoal
    }

    private func sliderRow(_ title: LocalizedStringKey, value: Binding<Double>,
                           range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)").foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: 1).tint(Theme.Palette.brand)
        }
    }

    private func save() {
        draft.manualCalorieGoal = useManualGoal ? manualGoal : nil
        appState.profile = draft
        Haptics.success()
        dismiss()
    }
}
