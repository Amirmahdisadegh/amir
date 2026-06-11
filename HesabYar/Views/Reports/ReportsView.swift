import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var expenses: [Expense]
    @State private var selectedPeriod: ReportPeriod = .thisMonth
    @State private var chartType: ChartType = .bar
    @State private var shareURL: URL? = nil
    @State private var showingShareSheet = false
    @State private var viewModel = ExpenseViewModel()

    enum ReportPeriod: String, CaseIterable {
        case thisMonth = "این ماه"
        case last3Months = "۳ ماه اخیر"
        case last6Months = "۶ ماه اخیر"
        case thisYear = "امسال"
    }

    enum ChartType: String, CaseIterable {
        case bar = "نمودار میله‌ای"
        case pie = "نمودار دایره‌ای"
        case line = "نمودار خطی"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period selector
                    periodSelector

                    // Summary cards
                    summarySection

                    // Chart
                    chartSection

                    // Category breakdown
                    categoryBreakdownSection

                    // Monthly trend
                    if selectedPeriod != .thisMonth {
                        monthlyTrendSection
                    }

                    // Top expenses
                    topExpensesSection

                    // Export buttons
                    exportSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.t("Reports", "گزارش‌ها"))
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        Picker("بازه", selection: $selectedPeriod) {
            ForEach(ReportPeriod.allCases, id: \.rawValue) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 8)
    }

    // MARK: - Summary

    private var summarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "کل هزینه",
                value: filteredTotal.formattedCompact,
                icon: "sum",
                iconColor: .purple
            )
            StatCard(
                title: "میانگین روزانه",
                value: (filteredTotal / max(Double(dayCount), 1)).formattedCompact,
                icon: "calendar",
                iconColor: .orange
            )
            StatCard(
                title: "تعداد تراکنش",
                value: "\(filteredExpenses.count)",
                icon: "list.number",
                iconColor: .blue
            )
            StatCard(
                title: "بزرگترین هزینه",
                value: (filteredExpenses.max(by: { $0.amount < $1.amount })?.amount ?? 0).formattedCompact,
                icon: "arrow.up.right",
                iconColor: .red
            )
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("نمودار هزینه‌ها")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Picker("نوع نمودار", selection: $chartType) {
                    ForEach(ChartType.allCases, id: \.rawValue) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }

            Group {
                switch chartType {
                case .bar:
                    barChart
                case .pie:
                    pieChart
                case .line:
                    lineChart
                }
            }
            .frame(height: 220)
        }
        .cardStyle()
    }

    private var barChart: some View {
        Chart(categoryData, id: \.0.rawValue) { item in
            BarMark(
                x: .value("دسته", item.0.displayName),
                y: .value("مبلغ", item.1)
            )
            .foregroundStyle(item.0.color)
            .cornerRadius(6)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formattedCompact)
                            .font(.system(size: 9))
                    }
                }
            }
        }
    }

    private var pieChart: some View {
        Chart(categoryData, id: \.0.rawValue) { item in
            SectorMark(
                angle: .value("مبلغ", item.1),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(item.0.color)
            .cornerRadius(4)
            .annotation(position: .overlay) {
                if item.1 / filteredTotal > 0.08 {
                    Text("\(Int((item.1 / filteredTotal) * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var lineChart: some View {
        Chart(viewModel.dailySpending(filteredExpenses), id: \.day) { item in
            LineMark(
                x: .value("روز", item.day),
                y: .value("مبلغ", item.total)
            )
            .foregroundStyle(Color.appPrimary)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("روز", item.day),
                y: .value("مبلغ", item.total)
            )
            .foregroundStyle(Color.appPrimary.opacity(0.1))
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formattedCompact).font(.system(size: 9))
                    }
                }
            }
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("جزئیات دسته‌بندی")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 10) {
                ForEach(categoryData, id: \.0.rawValue) { item in
                    VStack(spacing: 6) {
                        HStack {
                            Circle()
                                .fill(item.0.color)
                                .frame(width: 10, height: 10)
                            Image(systemName: item.0.icon)
                                .foregroundColor(item.0.color)
                                .font(.caption)
                            Text(item.0.displayName)
                                .font(.subheadline)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.1.formattedAsCurrency)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("\(Int((item.1 / filteredTotal) * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.systemGray5)).frame(height: 4)
                                Capsule()
                                    .fill(item.0.color)
                                    .frame(width: geo.size.width * CGFloat(item.1 / max(filteredTotal, 1)), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Monthly Trend

    private var monthlyTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("روند ماهانه")
                .font(.headline)
                .fontWeight(.bold)

            Chart(viewModel.last6MonthsData(expenses), id: \.month) { item in
                BarMark(
                    x: .value("ماه", item.month),
                    y: .value("مبلغ", item.total)
                )
                .foregroundStyle(Color.appPrimary.gradient)
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.formattedCompact).font(.system(size: 9))
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Top Expenses

    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("بزرگترین هزینه‌ها")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 0) {
                ForEach(Array(filteredExpenses.sorted { $0.amount > $1.amount }.prefix(5).enumerated()), id: \.offset) { idx, expense in
                    HStack(spacing: 12) {
                        Text("\(idx + 1)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(width: 20)

                        ZStack {
                            Circle().fill(expense.category.color.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: expense.category.icon)
                                .foregroundColor(expense.category.color)
                                .font(.system(size: 14))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.title).font(.subheadline).lineLimit(1)
                            Text(expense.date.farsiFormatted).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(expense.amount.formattedAsCurrency)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 8)
                    if idx < 4 { Divider().padding(.leading, 60) }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Export

    private var exportSection: some View {
        VStack(spacing: 10) {
            Button {
                if let url = ExportService.shared.exportToCSV(expenses: filteredExpenses) {
                    shareURL = url
                    showingShareSheet = true
                }
            } label: {
                Label("خروجی CSV", systemImage: "tablecells")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                let cal = Calendar.current
                let month = cal.component(.month, from: Date())
                let year = cal.component(.year, from: Date())
                if let url = ExportService.shared.exportToPDF(expenses: filteredExpenses, month: month, year: year) {
                    shareURL = url
                    showingShareSheet = true
                }
            } label: {
                Label("خروجی PDF", systemImage: "doc.richtext")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Computed

    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        switch selectedPeriod {
        case .thisMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: comps)!
            return expenses.filter { $0.date >= start }
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -3, to: now)!
            return expenses.filter { $0.date >= start }
        case .last6Months:
            let start = calendar.date(byAdding: .month, value: -6, to: now)!
            return expenses.filter { $0.date >= start }
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: now)
            let start = calendar.date(from: comps)!
            return expenses.filter { $0.date >= start }
        }
    }

    private var filteredTotal: Double { filteredExpenses.reduce(0) { $0 + $1.amount } }

    private var categoryData: [(ExpenseCategory, Double)] {
        var totals: [ExpenseCategory: Double] = [:]
        for e in filteredExpenses { totals[e.category, default: 0] += e.amount }
        return totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var dayCount: Int {
        switch selectedPeriod {
        case .thisMonth: return Calendar.current.component(.day, from: Date())
        case .last3Months: return 90
        case .last6Months: return 180
        case .thisYear: return Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 365
        }
    }
}

