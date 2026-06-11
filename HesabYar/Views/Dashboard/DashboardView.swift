import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var expenses: [Expense]
    @Query private var debts: [Debt]
    @Query private var budgets: [Budget]
    @State private var showingAddExpense = false
    @State private var showingScanner = false
    @State private var insights: [FinancialInsight] = []

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Full-bleed gradient background
                LinearGradient(
                    colors: settings.theme.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Custom header (replaces NavBar)
                        headerSection
                            .padding(.top, safeAreaTop + 8)

                        // Hero card
                        heroCard

                        // Stats grid
                        statsGrid

                        // Budget progress
                        if !activeBudgets.isEmpty {
                            budgetSection
                        }

                        // Spending chart
                        if !categoryData.isEmpty {
                            chartSection
                        }

                        // AI Insights
                        if !insights.isEmpty {
                            insightsSection
                        }

                        // Recent transactions
                        recentSection

                        // Debt reminder
                        if !pendingDebts.isEmpty {
                            debtSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .ignoresSafeArea(.all)
        }
        .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
        .sheet(isPresented: $showingScanner) { ReceiptScannerView() }
        .onAppear { insights = AIService.shared.analyzeOffline(expenses: expenses) }
    }

    // MARK: - Safe Area Helper

    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 44
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text("HesabYar")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 14) {
                Button {
                    showingScanner = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }

                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.25))
                        .clipShape(Circle())
                }
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 6) {
            Text(settings.t("This Month", "این ماه"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))

            Text(monthlyTotal.formattedAsCurrency)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 16) {
                Label("\(monthlyExpenses.count) \(settings.t("transactions", "تراکنش"))", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))

                Divider()
                    .frame(height: 12)
                    .overlay(.white.opacity(0.4))

                Label("\(settings.t("Daily avg", "میانگین روز")) \(dailyAverage.formattedCompact)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            glassStatCard(
                title: settings.t("I Owe", "بدهکار"),
                value: totalIOwe.formattedCompact,
                icon: "arrow.up.circle.fill",
                color: .red
            )
            glassStatCard(
                title: settings.t("Owed to Me", "طلب"),
                value: totalOwedToMe.formattedCompact,
                icon: "arrow.down.circle.fill",
                color: .green
            )
        }
    }

    private func glassStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 18, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(settings.t("Budgets", "بودجه‌ها"), icon: "chart.bar.fill")

            VStack(spacing: 8) {
                ForEach(activeBudgets, id: \.id) { budget in
                    BudgetProgressRow(budget: budget, expenses: expenses)
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(settings.t("Spending by Category", "هزینه بر اساس دسته"), icon: "chart.pie.fill")

            VStack(spacing: 14) {
                Chart(categoryData, id: \.0.rawValue) { item in
                    SectorMark(
                        angle: .value(settings.t("Amount", "مبلغ"), item.1),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.0.color)
                    .cornerRadius(4)
                }
                .frame(height: 180)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(categoryData.prefix(6), id: \.0.rawValue) { item in
                        HStack(spacing: 6) {
                            Circle().fill(item.0.color).frame(width: 8, height: 8)
                            Text(item.0.displayName).font(.caption).lineLimit(1)
                            Spacer()
                            Text(item.1.formattedCompact).font(.caption).fontWeight(.medium)
                        }
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(settings.t("Smart Analysis", "تحلیل هوشمند"), icon: "brain")
                Spacer()
                Text(settings.t("Offline", "آفلاین"))
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(settings.theme.primary.opacity(0.15))
                    .foregroundStyle(settings.theme.primary)
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(insights) { insight in
                        InsightCard(insight: insight).frame(width: 220)
                    }
                }
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(settings.t("Recent", "آخرین تراکنش‌ها"), icon: "clock.fill")
                Spacer()
                NavigationLink(settings.t("See All", "همه")) {
                    ExpenseListView()
                }
                .font(.subheadline)
                .foregroundStyle(settings.theme.primary)
            }

            if recentExpenses.isEmpty {
                EmptyStateView(
                    icon: "receipt",
                    title: settings.t("No Expenses Yet", "هنوز هزینه‌ای ثبت نشده"),
                    subtitle: settings.t("Add your first expense", "اولین هزینه‌ات رو اضافه کن"),
                    action: { showingAddExpense = true },
                    actionTitle: settings.t("Add Expense", "افزودن هزینه")
                )
                .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(recentExpenses, id: \.id) { expense in
                        ExpenseRow(expense: expense).padding(.horizontal, 4)
                        if expense.id != recentExpenses.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Debt Section

    private var debtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(settings.t("Debt Reminders", "یادآوری بدهی‌ها"), icon: "person.2.fill")

            VStack(spacing: 8) {
                ForEach(pendingDebts.prefix(3), id: \.id) { debt in
                    HStack(spacing: 12) {
                        Image(systemName: debt.isOwedToMe ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundStyle(debt.isOwedToMe ? .green : .red)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(debt.personName).font(.subheadline).fontWeight(.medium)
                            if let days = debt.remainingDays {
                                Text(days < 0 ? settings.t("Overdue", "سررسید گذشته") : "\(days) \(settings.t("days left", "روز مانده"))")
                                    .font(.caption)
                                    .foregroundStyle(days < 0 ? .red : .secondary)
                            }
                        }
                        Spacer()
                        Text(debt.amount.formattedCompact)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(debt.isOwedToMe ? .green : .red)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .fontWeight(.bold)
    }

    // MARK: - Computed

    private var monthlyExpenses: [Expense] {
        let cal = Calendar.current
        let now = Date()
        return expenses.filter {
            cal.component(.month, from: $0.date) == cal.component(.month, from: now) &&
            cal.component(.year, from: $0.date) == cal.component(.year, from: now)
        }
    }

    private var monthlyTotal: Double { monthlyExpenses.reduce(0) { $0 + $1.amount } }
    private var dailyAverage: Double {
        let day = Calendar.current.component(.day, from: Date())
        return day > 0 ? monthlyTotal / Double(day) : 0
    }
    private var categoryData: [(ExpenseCategory, Double)] {
        var totals: [ExpenseCategory: Double] = [:]
        for e in monthlyExpenses { totals[e.category, default: 0] += e.amount }
        return totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    private var recentExpenses: [Expense] {
        expenses.sorted { $0.date > $1.date }.prefix(5).map { $0 }
    }
    private var pendingDebts: [Debt] { debts.filter { !$0.isPaid } }
    private var totalOwedToMe: Double { debts.filter { $0.isOwedToMe && !$0.isPaid }.reduce(0) { $0 + $1.amount } }
    private var totalIOwe: Double { debts.filter { !$0.isOwedToMe && !$0.isPaid }.reduce(0) { $0 + $1.amount } }
    private var activeBudgets: [Budget] { budgets.filter { $0.isActive } }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return settings.t("Good Morning", "صبح بخیر")
        case 12..<17: return settings.t("Good Afternoon", "ظهر بخیر")
        case 17..<21: return settings.t("Good Evening", "عصر بخیر")
        default:      return settings.t("Good Night", "شب بخیر")
        }
    }
}

// MARK: - Budget Progress Row

struct BudgetProgressRow: View {
    @Environment(AppSettings.self) private var settings
    let budget: Budget
    let expenses: [Expense]

    private var spent: Double {
        let cal = Calendar.current
        return expenses
            .filter {
                $0.category == budget.category &&
                cal.component(.month, from: $0.date) == budget.month &&
                cal.component(.year, from: $0.date) == budget.year
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var progress: Double {
        budget.monthlyLimit > 0 ? min(spent / budget.monthlyLimit, 1.0) : 0
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .red }
        if progress >= budget.notifyAt { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: budget.category.icon)
                    .foregroundStyle(budget.category.color)
                    .font(.caption)
                Text(budget.category.displayName)
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Text("\(spent.formattedCompact) / \(budget.monthlyLimit.formattedCompact)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 6)
                    Capsule().fill(progressColor)
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: FinancialInsight

    private var cardColor: Color {
        switch insight.type {
        case .warning:     return .orange
        case .tip:         return .blue
        case .achievement: return .green
        case .info:        return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: insight.icon).font(.title3).foregroundStyle(cardColor)
                Spacer()
                Image(systemName: insight.type == .warning ? "exclamationmark.triangle.fill" :
                                  insight.type == .tip ? "lightbulb.fill" :
                                  insight.type == .achievement ? "star.fill" : "info.circle.fill")
                    .foregroundStyle(cardColor.opacity(0.6)).font(.caption)
            }
            Text(insight.title).font(.subheadline).fontWeight(.bold)
            Text(insight.detail).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            if let amount = insight.amount {
                Text(amount.formattedAsCurrency).font(.caption).fontWeight(.semibold).foregroundStyle(cardColor)
            }
        }
        .cardStyle()
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardColor.opacity(0.2), lineWidth: 1))
    }
}
