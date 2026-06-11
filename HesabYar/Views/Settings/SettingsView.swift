import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var debts: [Debt]
    @Query private var budgets: [Budget]
    @Query private var subscriptions: [SubscriptionRecord]

    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("weekly_summary")        private var weeklySummary = true

    @State private var showClearAlert = false
    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil

    var body: some View {
        NavigationStack {
            List {
                // MARK: - App Header Card
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            LinearGradient(
                                colors: settings.theme.gradient,
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2).foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HesabYar")
                                .font(.title3).fontWeight(.bold)
                            Text(settings.t("Smart Expense Tracker", "ردیاب هزینه هوشمند"))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("v1.1  ·  iOS 17+")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Appearance
                Section {
                    // Language
                    HStack {
                        Label(settings.t("Language", "زبان"), systemImage: "globe")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { settings.language },
                            set: { settings.language = $0 }
                        )) {
                            Text("English").tag("en")
                            Text("فارسی").tag("fa")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }

                    // Theme
                    VStack(alignment: .leading, spacing: 10) {
                        Label(settings.t("Color Theme", "رنگ‌بندی"), systemImage: "paintpalette.fill")
                            .font(.body)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                                Button {
                                    settings.theme = theme
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(theme.primary)
                                            .frame(width: 38, height: 38)
                                            .shadow(color: theme.primary.opacity(0.4), radius: 4)
                                        if settings.theme == theme {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label(settings.t("Appearance", "ظاهر"), systemImage: "paintbrush")
                }

                // MARK: - Data Summary
                Section {
                    statsRow(
                        settings.t("Expenses", "هزینه‌ها"),
                        value: "\(expenses.count)",
                        icon: "creditcard", color: .blue
                    )
                    statsRow(
                        settings.t("Active Subscriptions", "اشتراک‌های فعال"),
                        value: "\(subscriptions.filter { $0.isActive }.count)",
                        icon: "arrow.clockwise.circle", color: .purple
                    )
                    statsRow(
                        settings.t("Open Debts", "بدهی‌های باز"),
                        value: "\(debts.filter { !$0.isPaid }.count)",
                        icon: "person.2", color: .orange
                    )
                    statsRow(
                        settings.t("Total Spending", "کل هزینه"),
                        value: expenses.reduce(0) { $0 + $1.amount }.formattedCompact,
                        icon: "sum", color: .red
                    )
                } header: {
                    Label(settings.t("Summary", "خلاصه"), systemImage: "chart.bar.xaxis")
                }

                // MARK: - Navigate To
                Section {
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label(settings.t("Reports & Charts", "گزارش‌ها"), systemImage: "chart.pie.fill")
                    }
                    NavigationLink {
                        DebtTrackerView()
                    } label: {
                        Label(settings.t("Debt Tracker", "بدهی‌ها"), systemImage: "person.2.fill")
                    }
                    NavigationLink {
                        BudgetView()
                    } label: {
                        Label(settings.t("Budgets", "بودجه‌ها"), systemImage: "chart.bar.fill")
                    }
                } header: {
                    Label(settings.t("More Features", "امکانات بیشتر"), systemImage: "rectangle.stack")
                }

                // MARK: - Notifications
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label(settings.t("Notifications", "اعلان‌ها"), systemImage: "bell.fill")
                    }
                    .onChange(of: notificationsEnabled) {
                        if notificationsEnabled {
                            Task { await NotificationService.shared.requestPermission() }
                        }
                    }

                    if notificationsEnabled {
                        Toggle(isOn: $weeklySummary) {
                            Label(settings.t("Weekly Summary", "خلاصه هفتگی"), systemImage: "calendar.badge.clock")
                        }
                        .onChange(of: weeklySummary) {
                            if weeklySummary { NotificationService.shared.scheduleWeeklySummary() }
                        }
                    }
                } header: {
                    Label(settings.t("Notifications", "اعلان‌ها"), systemImage: "bell")
                }

                // MARK: - Export
                Section {
                    Button {
                        if let url = ExportService.shared.exportToCSV(expenses: expenses) {
                            exportURL = url
                            showShareSheet = true
                        }
                    } label: {
                        Label(settings.t("Export CSV", "خروجی CSV"), systemImage: "tablecells")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        let cal = Calendar.current
                        if let url = ExportService.shared.exportToPDF(
                            expenses: expenses,
                            month: cal.component(.month, from: Date()),
                            year: cal.component(.year, from: Date())
                        ) {
                            exportURL = url
                            showShareSheet = true
                        }
                    } label: {
                        Label(settings.t("Export Monthly PDF", "خروجی PDF ماهانه"), systemImage: "doc.richtext")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Label(settings.t("Export", "خروجی داده"), systemImage: "square.and.arrow.up")
                }

                // MARK: - Danger Zone
                Section {
                    Button(role: .destructive) { showClearAlert = true } label: {
                        Label(settings.t("Clear All Data", "پاک کردن همه داده‌ها"), systemImage: "trash.fill")
                    }
                } header: {
                    Label(settings.t("Danger Zone", "خطر"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(settings.t("Settings", "تنظیمات"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(settings.t("Clear All Data?", "پاک کردن همه داده‌ها؟"),
                   isPresented: $showClearAlert) {
                Button(settings.t("Delete", "حذف"), role: .destructive) { clearAll() }
                Button(settings.t("Cancel", "انصراف"), role: .cancel) {}
            } message: {
                Text(settings.t(
                    "All expenses, debts, subscriptions and budgets will be deleted. This cannot be undone.",
                    "تمام داده‌ها حذف می‌شوند. این عمل برگشت‌ناپذیر است."
                ))
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL { ShareSheet(items: [url]) }
            }
        }
    }

    private func statsRow(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            Text(title)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func clearAll() {
        expenses.forEach { modelContext.delete($0) }
        debts.forEach { modelContext.delete($0) }
        budgets.forEach { modelContext.delete($0) }
        subscriptions.forEach { modelContext.delete($0) }
    }
}
