import SwiftUI
import SwiftData

struct AccountView: View {
    @Environment(CloudAccount.self) private var cloud
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var foods: [FoodEntry]
    @Query private var weights: [WeightEntry]

    @State private var email = ""
    @State private var password = ""
    @State private var keyInput = ""
    @State private var projectInput = ""
    @State private var showConfig = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    header
                    if !cloud.isConfigured || showConfig {
                        configCard
                    }
                    if cloud.isConfigured {
                        if cloud.isSignedIn { signedInCard } else { authCard }
                    }
                    if let status = cloud.status {
                        Text(status)
                            .font(Theme.Font.caption(12))
                            .foregroundStyle(Theme.Palette.calorie)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(Theme.Space.md)
            }
            .background(AuroraBackground())
            .navigationTitle("account.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }.bold()
                }
            }
            .onAppear {
                keyInput = cloud.apiKey ?? ""
                projectInput = cloud.projectID
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: cloud.isSignedIn ? "checkmark.icloud.fill" : "icloud")
                .font(.system(size: 40))
                .foregroundStyle(Theme.energyGradient)
            Text(cloud.isSignedIn ? (cloud.email ?? "") : "account.subtitle")
                .font(Theme.Font.title(17))
                .foregroundStyle(Theme.textPrimary(scheme))
            if let last = cloud.lastSync {
                Text("account.lastSync \(last.formatted(date: .abbreviated, time: .shortened))")
                    .font(Theme.Font.caption(11))
                    .foregroundStyle(Theme.textSecondary(scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var configCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("account.setup")
                .font(Theme.Font.title(16))
                .foregroundStyle(Theme.textPrimary(scheme))
            field("Firebase Web API Key", text: $keyInput, secure: true)
            field("Project ID", text: $projectInput, secure: false)
            Button("action.save") {
                cloud.apiKey = keyInput.trimmingCharacters(in: .whitespaces)
                cloud.projectID = projectInput.trimmingCharacters(in: .whitespaces)
                showConfig = false
                Haptics.success()
            }
            .buttonStyle(PrimaryButtonStyle())
            Text("account.setupHelp")
                .font(Theme.Font.caption(11))
                .foregroundStyle(Theme.textSecondary(scheme))
        }
        .cardSurface()
    }

    private var authCard: some View {
        VStack(spacing: 12) {
            field("account.email", text: $email, secure: false)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            field("account.password", text: $password, secure: true)
            Button("account.signIn") {
                Task { _ = await cloud.signIn(email: email, password: password) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(cloud.busy)
            Button("account.signUp") {
                Task { _ = await cloud.signUp(email: email, password: password) }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(cloud.busy)
        }
        .cardSurface()
    }

    private var signedInCard: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    if await cloud.backup(snapshot()) { Haptics.success() }
                }
            } label: {
                Label("account.backup", systemImage: "arrow.up.to.line")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(cloud.busy)

            Button {
                Task {
                    if let snap = await cloud.restore() {
                        applyRestore(snap); Haptics.success()
                    }
                }
            } label: {
                Label("account.restore", systemImage: "arrow.down.to.line")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(cloud.busy)

            if cloud.busy { ProgressView().tint(Theme.Palette.brand) }

            Button("account.signOut") { cloud.signOut() }
                .font(Theme.Font.caption(13))
                .foregroundStyle(Theme.Palette.danger)
                .padding(.top, 4)
        }
        .cardSurface()
    }

    private func field(_ placeholder: LocalizedStringKey, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure { SecureField(placeholder, text: text) }
            else { TextField(placeholder, text: text) }
        }
        .autocorrectionDisabled()
        .font(.system(.body, design: .monospaced))
        .padding(12)
        .background(Theme.chipFill(scheme),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    // MARK: Snapshot

    private func snapshot() -> CloudSnapshot {
        var s = CloudSnapshot()
        s.foods = foods.map(FoodDTO.init)
        s.weights = weights.map(WeightDTO.init)
        s.profile = appState.profile
        s.burnedByDay = appState.burnedByDay
        s.waterByDay = appState.waterByDay
        s.waterGoalML = appState.waterGoalML
        return s
    }

    private func applyRestore(_ s: CloudSnapshot) {
        for f in foods { context.delete(f) }
        for w in weights { context.delete(w) }
        for dto in s.foods { context.insert(dto.makeEntry()) }
        for dto in s.weights { context.insert(dto.makeEntry()) }
        try? context.save()
        appState.profile = s.profile
        appState.burnedByDay = s.burnedByDay
        appState.waterByDay = s.waterByDay
        appState.waterGoalML = s.waterGoalML
    }
}
