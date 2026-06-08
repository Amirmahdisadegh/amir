import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query private var expenses: [Expense]
    @State private var showingAddBudget = false
    @State private var selectedBudget: Budget? = nil

    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var activeBudgets: [Budget] {
        budgets.filter { $0.month == currentMonth && $0.year == currentYear && $0.isActive }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if activeBudgets.isEmpty {
                        Spacer().frame(height: 60)
                        EmptyStateView(
                            icon: "chart.bar.fill",
                            title: "بودجه‌ای تعریف نشده",
                            subtitle: "برای هر دسته بودجه ماهانه تعریف کن تا هزینه‌هایت رو کنترل کنی",
                            action: { showingAddBudget = true },
                            actionTitle: "تعریف بودجه"
                        )
                    } else {
                        // Overall progress
                        overallProgressSection

                        // Individual budgets
                        VStack(alignment: .leading, spacing: 12) {
                            Text("بودجه‌های ماهانه")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)

                            ForEach(activeBudgets, id: \.id) { budget in
                                BudgetDetailCard(
                                    budget: budget,
                                    expenses: expenses
                                )
                                .padding(.horizontal, 16)
                                .contextMenu {
                                    Button("ویرایش") { selectedBudget = budget }
                                    Button("غیرفعال", role: .destructive) { budget.isActive = false }
                                }
                            }
                        }

                        // Tips
                        budgetTipsSection
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("بودجه‌بندی")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBudget) {
                AddBudgetView()
            }
            .sheet(item: $selectedBudget) { budget in
                AddBudgetView(editingBudget: budget)
            }
        }
    }

    // MARK: - Overall Progress

    private var overallProgressSection: some View {
        VStack(spacing: 12) {
            let totalBudget = activeBudgets.reduce(0) { $0 + $1.monthlyLimit }
            let totalSpent = activeBudgets.reduce(0.0) { sum, budget in
                sum + spentFor(budget)
            }
            let progress = totalBudget > 0 ? totalSpent / totalBudget : 0

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("بودجه کل این ماه")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(progress > 1.0 ? .red : progress > 0.8 ? .orange : .green)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                        Capsule()
                            .fill(progress > 1.0 ? Color.red : progress > 0.8 ? Color.orange : Color.green)
                            .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 12)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("خرج شده: \(totalSpent.formattedCompact)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("بودجه: \(totalBudget.formattedCompact)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if progress > 1.0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("بودجه کل شما \((totalSpent - totalBudget).formattedCompact) تومان تجاوز کرده!")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .cardStyle()
        .padding(.horizontal, 16)
    }

    // MARK: - Tips

    private var budgetTipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("نکات مدیریت بودجه")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                TipRow(icon: "50.circle.fill", color: .blue,
                       text: "قانون ۵۰-۳۰-۲۰: ۵۰٪ ضروریات، ۳۰٪ خواسته‌ها، ۲۰٪ پس‌انداز")
                TipRow(icon: "bell.fill", color: .orange,
                       text: "هشدار در ۸۰٪ مصرف بودجه تنظیم کنید")
                TipRow(icon: "chart.line.downtrend.xyaxis", color: .green,
                       text: "هر ماه بودجه را بر اساس هزینه‌های واقعی تنظیم کنید")
            }
        }
        .cardStyle()
        .padding(.horizontal, 16)
    }

    private func spentFor(_ budget: Budget) -> Double {
        expenses
            .filter {
                $0.category == budget.category &&
                Calendar.current.component(.month, from: $0.date) == budget.month &&
                Calendar.current.component(.year, from: $0.date) == budget.year
            }
            .reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Budget Detail Card

struct BudgetDetailCard: View {
    let budget: Budget
    let expenses: [Expense]

    private var spent: Double {
        expenses
            .filter {
                $0.category == budget.category &&
                Calendar.current.component(.month, from: $0.date) == budget.month &&
                Calendar.current.component(.year, from: $0.date) == budget.year
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var progress: Double { budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : 0 }
    private var remaining: Double { budget.monthlyLimit - spent }

    private var statusColor: Color {
        if progress >= 1.0 { return .red }
        if progress >= budget.notifyAt { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(budget.category.color.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: budget.category.icon)
                            .foregroundColor(budget.category.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(budget.category.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("بودجه: \(budget.monthlyLimit.formattedCompact)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                    Text(progress >= 1.0 ? "تجاوز!" : remaining >= 0 ? "باقیمانده: \(remaining.formattedCompact)" : "")
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 8)
                    Capsule()
                        .fill(statusColor)
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("خرج شده: \(spent.formattedAsCurrency)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("از \(budget.monthlyLimit.formattedAsCurrency)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Add Budget View

struct AddBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingBudget: Budget? = nil

    @State private var selectedCategory: ExpenseCategory = .food
    @State private var limitText = ""
    @State private var notifyAt = 0.8

    var isValid: Bool { (Double(limitText) ?? 0) > 0 }
    var isEditing: Bool { editingBudget != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("دسته‌بندی") {
                    if !isEditing {
                        Picker("دسته", selection: $selectedCategory) {
                            ForEach(ExpenseCategory.allCases) { cat in
                                Label(cat.displayName, systemImage: cat.icon).tag(cat)
                            }
                        }
                    } else {
                        Label(editingBudget!.category.displayName, systemImage: editingBudget!.category.icon)
                    }
                }

                Section("بودجه ماهانه") {
                    HStack {
                        TextField("مبلغ", text: $limitText)
                            .keyboardType(.decimalPad)
                        Text("تومان").foregroundColor(.secondary)
                    }

                    // Quick amounts
                    HStack(spacing: 8) {
                        ForEach([500_000.0, 1_000_000.0, 2_000_000.0, 5_000_000.0], id: \.self) { amt in
                            Button(amt.formattedCompact) { limitText = "\(Int(amt))" }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }

                Section("هشدار") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("هشدار در \(Int(notifyAt * 100))% مصرف بودجه")
                            .font(.subheadline)
                        Slider(value: $notifyAt, in: 0.5...0.95, step: 0.05)
                            .tint(.orange)
                        HStack {
                            Text("۵۰%").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("۹۵%").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "ویرایش بودجه" : "بودجه جدید")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("انصراف") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "ذخیره" : "افزودن") { save(); dismiss() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if let b = editingBudget {
                    selectedCategory = b.category
                    limitText = "\(Int(b.monthlyLimit))"
                    notifyAt = b.notifyAt
                }
            }
        }
    }

    private func save() {
        let limit = Double(limitText) ?? 0
        if let existing = editingBudget {
            existing.monthlyLimit = limit
            existing.notifyAt = notifyAt
        } else {
            let budget = Budget(
                category: selectedCategory,
                monthlyLimit: limit,
                notifyAt: notifyAt
            )
            modelContext.insert(budget)
        }
    }
}
