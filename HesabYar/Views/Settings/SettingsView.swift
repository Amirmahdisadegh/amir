import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var debts: [Debt]
    @Query private var budgets: [Budget]

    @AppStorage("default_currency") private var defaultCurrency = "IRR"
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("theme_mode") private var themeMode = "system"
    @AppStorage("claude_api_key") private var apiKey = ""

    @State private var showingClearDataAlert = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL? = nil
    @State private var showingAPIKeyInput = false
    @State private var tempAPIKey = ""

    let currencies = ["IRR", "USD", "EUR", "GBP", "AED", "TRY"]

    var body: some View {
        NavigationStack {
            Form {
                // Profile/Summary section
                Section {
                    profileSection
                }
                .listRowBackground(Color(.secondarySystemBackground))

                // General settings
                Section("عمومی") {
                    Picker("واحد پول", selection: $defaultCurrency) {
                        ForEach(currencies, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }

                    Picker("تم", selection: $themeMode) {
                        Text("سیستم").tag("system")
                        Text("روشن").tag("light")
                        Text("تاریک").tag("dark")
                    }

                    Toggle(isOn: $notificationsEnabled) {
                        Label("اطلاعیه‌ها", systemImage: "bell.fill")
                    }
                }

                // AI Settings
                Section("هوش مصنوعی") {
                    Button {
                        showingAPIKeyInput = true
                        tempAPIKey = apiKey
                    } label: {
                        HStack {
                            Label("Claude API Key", systemImage: "key.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            if apiKey.isEmpty {
                                Text("تنظیم نشده")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("•••• تنظیم شده")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            Image(systemName: "chevron.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Label("حالت آفلاین", systemImage: "wifi.slash")
                            .font(.subheadline)
                        Text("بدون API Key، از تحلیل هوشمند محلی استفاده می‌شه")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Data management
                Section("مدیریت داده") {
                    Button {
                        if let url = ExportService.shared.exportToCSV(expenses: expenses) {
                            exportURL = url
                            showingExportSheet = true
                        }
                    } label: {
                        Label("خروجی CSV", systemImage: "tablecells")
                            .foregroundColor(.primary)
                    }

                    Button {
                        let cal = Calendar.current
                        let month = cal.component(.month, from: Date())
                        let year = cal.component(.year, from: Date())
                        if let url = ExportService.shared.exportToPDF(expenses: expenses, month: month, year: year) {
                            exportURL = url
                            showingExportSheet = true
                        }
                    } label: {
                        Label("خروجی PDF گزارش ماهانه", systemImage: "doc.richtext")
                            .foregroundColor(.primary)
                    }
                }

                // Statistics
                Section("آمار") {
                    LabeledContent("تعداد هزینه‌ها") { Text("\(expenses.count)") }
                    LabeledContent("تعداد بدهی‌ها") { Text("\(debts.count)") }
                    LabeledContent("تعداد بودجه‌ها") { Text("\(budgets.count)") }
                    LabeledContent("مجموع هزینه‌های ثبت‌شده") {
                        Text(expenses.reduce(0) { $0 + $1.amount }.formattedCompact + " تومان")
                    }
                }

                // Danger zone
                Section("خطر") {
                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Label("پاک کردن همه داده‌ها", systemImage: "trash.fill")
                    }
                }

                // About
                Section("درباره") {
                    LabeledContent("نسخه") { Text("1.0.0") }
                    LabeledContent("ساخته شده با") { Text("SwiftUI + Claude AI ❤️") }

                    Link(destination: URL(string: "https://anthropic.com")!) {
                        Label("Anthropic Claude", systemImage: "brain")
                    }
                }
            }
            .navigationTitle("تنظیمات")
            .navigationBarTitleDisplayMode(.large)
            .alert("پاک کردن همه داده‌ها", isPresented: $showingClearDataAlert) {
                Button("پاک کن", role: .destructive) { clearAllData() }
                Button("انصراف", role: .cancel) {}
            } message: {
                Text("این عملیات قابل بازگشت نیست. تمام هزینه‌ها، بدهی‌ها و بودجه‌ها حذف خواهند شد.")
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingAPIKeyInput) {
                NavigationStack {
                    Form {
                        Section {
                            SecureField("sk-ant-api...", text: $tempAPIKey)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        } header: {
                            Text("Claude API Key")
                        } footer: {
                            Text("از console.anthropic.com دریافت کنید. کلید فقط روی دستگاه شما ذخیره می‌شه.")
                        }
                    }
                    .navigationTitle("API Key")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("انصراف") { showingAPIKeyInput = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("ذخیره") {
                                apiKey = tempAPIKey
                                showingAPIKeyInput = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var profileSection: some View {
        HStack(spacing: 16) {
            ZStack {
                LinearGradient(colors: [.appPrimary, .appAccent],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("حسابیار")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("دستیار مالی هوشمند")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("نسخه ۱.۰.۰")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func clearAllData() {
        expenses.forEach { modelContext.delete($0) }
        debts.forEach { modelContext.delete($0) }
        budgets.forEach { modelContext.delete($0) }
    }
}
