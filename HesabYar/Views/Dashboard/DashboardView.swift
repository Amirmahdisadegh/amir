import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var expenses: [Expense]
    @Query private var debts: [Debt]
    @Query private var budgets: [Budget]
    @State private var viewModel = ExpenseViewModel()
    @State private var showingAddExpense = false
    @State private var showingScanner = false
    @State private var insights: [FinancialInsight] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header greeting
                    headerSection

                    // Summary cards
                    summaryCardsSection

                    // Budget progress
                    if !budgets.isEmpty {
                        budgetProgressSection
                    }

                    // Spending chart
                    spendingChartSection

                    // AI Insights
                    if !insights.isEmpty {
                        insightsSection
                    }

                    // Recent transactions
                    recentTransactionsSection

                    // Debt alert
                    if !pendingDebts.isEmpty {
                        debtAlertSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("حسابیار")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingScanner = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 20))
                        }
                        Button {
                            showingAddExpense = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView()
        }
        .sheet(isPresented: $showingScanner) {
            ReceiptScannerView()
        }
        .onAppear {
            insights = AIService.shared.analyzeOffline(expenses: expenses)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("وضعیت مالی این ماه")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Spacer()
            // Month badge
            Text(currentMonthName)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appPrimary.opacity(0.15))
                .foregroundColor(.appPrimary)
                .clipShape(Capsule())
        }
        .padding(.top, 8)
    }

    // MARK: - Summary Cards

    private var summaryCardsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "کل هزینه‌ها",
                value: monthlyTotal.formattedCompact,
                icon: "banknote.fill",
                iconColor: .red,
                subtitle: "\(monthlyExpenses.count) تراکنش"
            )

            StatCard(
                title: "میانگین روزانه",
                value: dailyAverage.formattedCompact,
                icon: "calendar",
                iconColor: .orange,
                subtitle: "تومان در روز"
            )

            StatCard(
                title: "بدهی دریافتنی",
                value: totalOwedToMe.formattedCompact,
                icon: "arrow.down.circle.fill",
                iconColor: .green,
                subtitle: "\(owedToMeCount) نفر"
            )

            StatCard(
                title: "بدهی پرداختنی",
                value: totalIOwe.formattedCompact,
                icon: "arrow.up.circle.fill",
                iconColor: .red,
                subtitle: "\(IOweCount) نفر"
            )
        }
    }

    // MARK: - Budget Progress

    private var budgetProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("بودجه‌ها")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                ForEach(activeBudgets, id: \.id) { budget in
                    BudgetProgressRow(budget: budget, expenses: expenses)
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Spending Chart

    private var spendingChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("هزینه‌ها بر اساس دسته")
                .font(.headline)
                .fontWeight(.bold)

            if categoryData.isEmpty {
                Text("هنوز هزینه‌ای ثبت نشده")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .cardStyle()
            } else {
                VStack(spacing: 12) {
                    Chart(categoryData, id: \.0.rawValue) { item in
                        SectorMark(
                            angle: .value("مبلغ", item.1),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(item.0.color)
                        .cornerRadius(4)
                    }
                    .frame(height: 200)

                    // Legend
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(categoryData.prefix(6), id: \.0.rawValue) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(item.0.color)
                                    .frame(width: 8, height: 8)
                                Text(item.0.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.1.formattedCompact)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - AI Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("تحلیل هوشمند", systemImage: "brain")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("آفلاین")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appAccent.opacity(0.15))
                    .foregroundColor(.appAccent)
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(insights) { insight in
                        InsightCard(insight: insight)
                            .frame(width: 220)
                    }
                }
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("آخرین تراکنش‌ها")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                NavigationLink("همه") {
                    ExpenseListView()
                }
                .font(.subheadline)
                .foregroundColor(.appPrimary)
            }

            if recentExpenses.isEmpty {
                EmptyStateView(
                    icon: "receipt",
                    title: "هنوز هزینه‌ای ثبت نشده",
                    subtitle: "اولین هزینه‌ات رو اضافه کن",
                    action: { showingAddExpense = true },
                    actionTitle: "افزودن هزینه"
                )
                .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(recentExpenses, id: \.id) { expense in
                        ExpenseRow(expense: expense)
                            .padding(.horizontal, 4)
                        if expense.id != recentExpenses.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Debt Alert

    private var debtAlertSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("یادآوری بدهی‌ها")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                ForEach(pendingDebts.prefix(3), id: \.id) { debt in
                    HStack {
                        Image(systemName: debt.isOwedToMe ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundColor(debt.isOwedToMe ? .green : .red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(debt.personName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let days = debt.remainingDays {
                                Text(days < 0 ? "سررسید گذشته" : "\(days) روز مانده")
                                    .font(.caption)
                                    .foregroundColor(days < 0 ? .red : .secondary)
                            }
                        }

                        Spacer()

                        Text(debt.amount.formattedCompact)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(debt.isOwedToMe ? .green : .red)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Computed Properties

    private var monthlyExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        return expenses.filter {
            calendar.component(.month, from: $0.date) == calendar.component(.month, from: now) &&
            calendar.component(.year, from: $0.date) == calendar.component(.year, from: now)
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
    private var owedToMeCount: Int { debts.filter { $0.isOwedToMe && !$0.isPaid }.count }
    private var IOweCount: Int { debts.filter { !$0.isOwedToMe && !$0.isPaid }.count }
    private var activeBudgets: [Budget] { budgets.filter { $0.isActive } }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "صبح بخیر"
        case 12..<17: return "ظهر بخیر"
        case 17..<21: return "عصر بخیر"
        default: return "شب بخیر"
        }
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fa_IR")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }
}

// MARK: - Budget Progress Row

struct BudgetProgressRow: View {
    let budget: Budget
    let expenses: [Expense]

    private var spent: Double {
        let cal = Calendar.current
        let now = Date()
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
                    .foregroundColor(budget.category.color)
                    .font(.caption)
                Text(budget.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(spent.formattedCompact) / \(budget.monthlyLimit.formattedCompact)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    Capsule()
                        .fill(progressColor)
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
        case .warning: return .orange
        case .tip: return .blue
        case .achievement: return .green
        case .info: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.title3)
                    .foregroundColor(cardColor)
                Spacer()
                Image(systemName: insight.type == .warning ? "exclamationmark.triangle.fill" :
                                  insight.type == .tip ? "lightbulb.fill" :
                                  insight.type == .achievement ? "star.fill" : "info.circle.fill")
                    .foregroundColor(cardColor.opacity(0.6))
                    .font(.caption)
            }

            Text(insight.title)
                .font(.subheadline)
                .fontWeight(.bold)

            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            if let amount = insight.amount {
                Text(amount.formattedAsCurrency)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(cardColor)
            }
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardColor.opacity(0.2), lineWidth: 1)
        )
    }
}
