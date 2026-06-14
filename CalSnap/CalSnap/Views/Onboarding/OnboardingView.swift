import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var page = 0
    @State private var draft = UserProfile()

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack {
                TabView(selection: $page) {
                    welcome.tag(0)
                    feature(icon: "camera.viewfinder",
                            title: "onb.snap.title", body: "onb.snap.body").tag(1)
                    feature(icon: "heart.text.square.fill",
                            title: "onb.health.title", body: "onb.health.body").tag(2)
                    profileStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                bottomBar
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Theme.energyGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: Theme.Palette.brand.opacity(0.4), radius: 24, y: 10)
                Image(systemName: "fork.knife")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("CalSnap")
                .font(Theme.Font.display(40))
                .foregroundStyle(Theme.textPrimary(scheme))
            Text("onb.welcome.body")
                .font(Theme.Font.body(16))
                .foregroundStyle(Theme.textSecondary(scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer(); Spacer()
        }
    }

    private func feature(icon: String, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(Theme.energyGradient)
            Text(title)
                .font(Theme.Font.display(28))
                .foregroundStyle(Theme.textPrimary(scheme))
                .multilineTextAlignment(.center)
            Text(body)
                .font(Theme.Font.body(16))
                .foregroundStyle(Theme.textSecondary(scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer(); Spacer()
        }
    }

    private var profileStep: some View {
        ScrollView {
            VStack(spacing: Theme.Space.md) {
                Text("onb.profile.title")
                    .font(Theme.Font.display(26))
                    .foregroundStyle(Theme.textPrimary(scheme))
                    .padding(.top, 30)
                Text("onb.profile.body")
                    .font(Theme.Font.body(14))
                    .foregroundStyle(Theme.textSecondary(scheme))
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    Picker("profile.sex", selection: $draft.sex) {
                        ForEach(Sex.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    labeled("profile.age", "\(draft.age)") {
                        Stepper("", value: $draft.age, in: 10...100).labelsHidden()
                    }
                    sliderRow("profile.weight", value: $draft.weightKg, range: 35...200, unit: "kg")
                    sliderRow("profile.height", value: $draft.heightCm, range: 120...220, unit: "cm")

                    Picker("profile.goal", selection: $draft.goal) {
                        ForEach(GoalDirection.allCases) {
                            Text(LocalizedStringKey($0.titleKey)).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .cardSurface()

                Text("onb.profile.goalPreview \(draft.calorieGoal)")
                    .font(Theme.Font.title(16))
                    .foregroundStyle(Theme.Palette.brand)
            }
            .padding(.horizontal, Theme.Space.md)
        }
    }

    private var bottomBar: some View {
        Button(page < 3 ? "onb.next" : "onb.start") {
            Haptics.tap()
            if page < 3 {
                withAnimation { page += 1 }
            } else {
                appState.profile = draft
                withAnimation { appState.hasOnboarded = true }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, Theme.Space.lg)
        .padding(.bottom, Theme.Space.md)
    }

    private func labeled(_ title: LocalizedStringKey, _ value: String,
                         @ViewBuilder control: () -> some View) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textPrimary(scheme))
            Spacer()
            Text(value).foregroundStyle(Theme.textSecondary(scheme)).monospacedDigit()
            control()
        }
    }

    private func sliderRow(_ title: LocalizedStringKey, value: Binding<Double>,
                           range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).foregroundStyle(Theme.textPrimary(scheme))
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .foregroundStyle(Theme.textSecondary(scheme)).monospacedDigit()
            }
            Slider(value: value, in: range, step: 1).tint(Theme.Palette.brand)
        }
    }
}
