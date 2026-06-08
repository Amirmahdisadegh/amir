import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var debts: [Debt]
    @Query private var budgets: [Budget]
    @Query private var subscriptions: [SubscriptionRecord]

    @AppStorage("default_currency")       private var defaultCurrency = "IRR"
    @AppStorage("notifications_enabled")  private var notificationsEnabled = true
    @AppStorage("weekly_summary")         private var weeklySummary = true
    @AppStorage("app_language")           private var appLanguage = "fa"
    @AppStorage("claude_api_key")         private var claudeKey = ""
    @AppStorage("openai_api_key")         private var openaiKey = ""
    @AppStorage("openai_model")           private var openaiModel = "gpt-4o-mini"
    @AppStorage("ai_provider")            private var aiProviderRaw = AIProvider.claude.rawValue

    @State private var showClearAlert = false
    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil
    @State private var showAPISheet = false
    @State private var pendingNotifCount = 0

    private var aiProvider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .claude
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Profile
                profileSection

                // MARK: Language
                Section {
                    Picker("زبان", selection: $appLanguage) {
                        Text("🇮🇷  فارسی").tag("fa")
                        Text("🇺🇸  English").tag("en")
                        Text("🇨🇳  中文").tag("zh")
                        Text("🇪🇸  Español").tag("es")
                    }
                } header: {
                    Label("زبان برنامه", systemImage: "globe")
                }

                // MARK: Currency
                Section {
                    Picker("واحد پیش‌فرض", selection: $defaultCurrency) {
                        Text("تومان (IRR)").tag("IRR")
                        Text("دلار (USD)").tag("USD")
                        Text("یورو (EUR)").tag("EUR")
                        Text("درهم (AED)").tag("AED")
                        Text("لیر (TRY)").tag("TRY")
                        Text("پوند (GBP)").tag("GBP")
                    }
                } header: {
                    Label("واحد پول", systemImage: "banknote")
                }

                // MARK: AI Provider
                Section {
                    Picker("ارائه‌دهنده AI", selection: $aiProviderRaw) {
                        ForEach(AIProvider.allCases, id: \.rawValue) { p in
                            Label(p.rawValue, systemImage: p.icon).tag(p.rawValue)
                        }
                    }
                    .pickerStyle(.inline)

                    Button {
                        showAPISheet = true
                    } label: {
                        HStack {
                            Label(aiProvider.apiKeyLabel, systemImage: "key.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Group {
                                switch aiProvider {
                                case .claude:
                                    Text(claudeKey.isEmpty ? "تنظیم نشده" : "✓ فعال")
                                        .foregroundColor(claudeKey.isEmpty ? .orange : .green)
                                case .openai:
                                    Text(openaiKey.isEmpty ? "تنظیم نشده" : "✓ فعال")
                                        .foregroundColor(openaiKey.isEmpty ? .orange : .green)
                                }
                            }
                            .font(.caption)
                            Image(systemName: "chevron.left").font(.caption).foregroundColor(.secondary)
                        }
                    }

                    if aiProvider == .openai {
                        Picker("مدل", selection: $openaiModel) {
                            Text("GPT-4o Mini (سریع‌تر)").tag("gpt-4o-mini")
                            Text("GPT-4o (دقیق‌تر)").tag("gpt-4o")
                            Text("GPT-4 Turbo").tag("gpt-4-turbo")
                        }
                    }
                } header: {
                    Label("هوش مصنوعی", systemImage: "brain")
                } footer: {
                    Text("بدون API Key، از تحلیل آفلاین استفاده می‌شه.")
                }

                // MARK: Notifications
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("نوتیفیکیشن‌ها", systemImage: "bell.fill")
                    }
                    .onChange(of: notificationsEnabled) {
                        if notificationsEnabled {
                            Task { await NotificationService.shared.requestPermission() }
                        }
                    }

                    if notificationsEnabled {
                        Toggle(isOn: $weeklySummary) {
                            Label("خلاصه هفتگی (دوشنبه‌ها)", systemImage: "calendar.badge.clock")
                        }
                        .onChange(of: weeklySummary) {
                            if weeklySummary { NotificationService.shared.scheduleWeeklySummary() }
                        }

                        Button {
                            Task {
                                pendingNotifCount = await NotificationService.shared.pendingCount()
                            }
                        } label: {
                            HStack {
                                Label("نوتیف‌های زمان‌بندی‌شده", systemImage: "clock.badge")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(pendingNotifCount) مورد").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("اعلان‌ها", systemImage: "bell")
                }

                // MARK: Stats
                Section {
                    statsRow("هزینه‌ها", value: "\(expenses.count) تراکنش", icon: "receipt", color: .blue)
                    statsRow("اشتراک‌ها", value: "\(subscriptions.filter { $0.isActive }.count) فعال", icon: "creditcard", color: .purple)
                    statsRow("بدهی‌ها", value: "\(debts.filter { !$0.isPaid }.count) باز", icon: "person.2", color: .orange)
                    statsRow("بودجه‌ها", value: "\(budgets.filter { $0.isActive }.count) فعال", icon: "chart.bar", color: .green)
                    statsRow("کل هزینه", value: expenses.reduce(0) { $0 + $1.amount }.formattedCompact + " تومان", icon: "sum", color: .red)
                } header: {
                    Label("آمار کلی", systemImage: "chart.bar.xaxis")
                }

                // MARK: Export
                Section {
                    Button {
                        if let url = ExportService.shared.exportToCSV(expenses: expenses) {
                            exportURL = url; showShareSheet = true
                        }
                    } label: {
                        Label("خروجی CSV", systemImage: "tablecells").foregroundColor(.primary)
                    }
                    Button {
                        let cal = Calendar.current
                        if let url = ExportService.shared.exportToPDF(
                            expenses: expenses,
                            month: cal.component(.month, from: Date()),
                            year: cal.component(.year, from: Date())
                        ) { exportURL = url; showShareSheet = true }
                    } label: {
                        Label("خروجی PDF ماهانه", systemImage: "doc.richtext").foregroundColor(.primary)
                    }
                } header: {
                    Label("خروجی داده", systemImage: "square.and.arrow.up")
                }

                // MARK: Danger
                Section {
                    Button(role: .destructive) { showClearAlert = true } label: {
                        Label("پاک کردن همه داده‌ها", systemImage: "trash.fill")
                    }
                } header: {
                    Label("خطر", systemImage: "exclamationmark.triangle.fill").foregroundColor(.red)
                }

                // MARK: About
                Section {
                    LabeledContent("نسخه") { Text("1.1.0") }
                    LabeledContent("iOS") { Text("17.0+") }
                    LabeledContent("ساخته شده با") { Text("SwiftUI ❤️") }
                } header: {
                    Label("درباره حسابیار", systemImage: "info.circle")
                }
            }
            .navigationTitle("تنظیمات")
            .navigationBarTitleDisplayMode(.large)
            .alert("پاک کردن همه داده‌ها", isPresented: $showClearAlert) {
                Button("پاک کن", role: .destructive) { clearAll() }
                Button("انصراف", role: .cancel) {}
            } message: {
                Text("تمام هزینه‌ها، بدهی‌ها، اشتراک‌ها و بودجه‌ها حذف می‌شوند. این عمل برگشت‌ناپذیر است.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL { ShareSheet(items: [url]) }
            }
            .sheet(isPresented: $showAPISheet) {
                APIKeySheet(
                    provider: aiProvider,
                    claudeKey: $claudeKey,
                    openaiKey: $openaiKey
                )
            }
            .onAppear {
                Task { pendingNotifCount = await NotificationService.shared.pendingCount() }
            }
        }
    }

    private func statsRow(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 24)
            Text(title)
            Spacer()
            Text(value).font(.subheadline).foregroundColor(.secondary)
        }
    }

    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    LinearGradient(colors: [.appPrimary, .appAccent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("حسابیار")
                        .font(.title3).fontWeight(.bold)
                    Text("دستیار مالی هوشمند")
                        .font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: aiProvider.icon).font(.caption2)
                        Text(aiProvider.rawValue.components(separatedBy: " ").first ?? "")
                            .font(.caption2)
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.appPrimary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func clearAll() {
        expenses.forEach { modelContext.delete($0) }
        debts.forEach { modelContext.delete($0) }
        budgets.forEach { modelContext.delete($0) }
        subscriptions.forEach { modelContext.delete($0) }
    }
}

// MARK: - API Key Sheet

struct APIKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let provider: AIProvider
    @Binding var claudeKey: String
    @Binding var openaiKey: String
    @State private var tempClaude = ""
    @State private var tempOpenAI = ""
    @State private var showClaude = false
    @State private var showOpenAI = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showClaude { TextField("sk-ant-...", text: $tempClaude).autocapitalization(.none).autocorrectionDisabled() }
                        else { SecureField("sk-ant-...", text: $tempClaude).autocapitalization(.none).autocorrectionDisabled() }
                        Button { showClaude.toggle() } label: {
                            Image(systemName: showClaude ? "eye.slash" : "eye").foregroundColor(.secondary)
                        }
                    }
                    if !tempClaude.isEmpty {
                        Button("پاک کن", role: .destructive) { tempClaude = "" }
                    }
                } header: { Text("Claude (Anthropic)") }
                footer: { Text("از console.anthropic.com دریافت کنید") }

                Section {
                    HStack {
                        if showOpenAI { TextField("sk-...", text: $tempOpenAI).autocapitalization(.none).autocorrectionDisabled() }
                        else { SecureField("sk-...", text: $tempOpenAI).autocapitalization(.none).autocorrectionDisabled() }
                        Button { showOpenAI.toggle() } label: {
                            Image(systemName: showOpenAI ? "eye.slash" : "eye").foregroundColor(.secondary)
                        }
                    }
                    if !tempOpenAI.isEmpty {
                        Button("پاک کن", role: .destructive) { tempOpenAI = "" }
                    }
                } header: { Text("OpenAI (ChatGPT)") }
                footer: { Text("از platform.openai.com دریافت کنید") }
            }
            .navigationTitle("کلیدهای API")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("انصراف") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ذخیره") {
                        claudeKey = tempClaude
                        openaiKey = tempOpenAI
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { tempClaude = claudeKey; tempOpenAI = openaiKey }
        }
    }
}
