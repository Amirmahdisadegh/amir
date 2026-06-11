import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var viewModel = ExpenseViewModel()
    @State private var showingAddExpense = false
    @State private var showingScanner = false
    @State private var selectedExpense: Expense? = nil
    @State private var expenseToDelete: Expense? = nil
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                if filteredExpenses.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: viewModel.searchText.isEmpty ? "receipt" : "magnifyingglass",
                        title: viewModel.searchText.isEmpty
                            ? settings.t("No Expenses", "هیچ هزینه‌ای ثبت نشده")
                            : settings.t("No Results", "نتیجه‌ای یافت نشد"),
                        subtitle: viewModel.searchText.isEmpty
                            ? settings.t("Add your first expense", "اولین هزینه‌ات رو اضافه کن")
                            : settings.t("Try a different search", "جستجوی دیگری امتحان کن"),
                        action: viewModel.searchText.isEmpty ? { showingAddExpense = true } : nil,
                        actionTitle: settings.t("Add Expense", "افزودن هزینه")
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(groupedExpenses.keys.sorted(by: >), id: \.self) { key in
                            Section(header: sectionHeader(for: key)) {
                                ForEach(groupedExpenses[key] ?? [], id: \.id) { expense in
                                    ExpenseRow(expense: expense)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedExpense = expense }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                expenseToDelete = expense
                                                showingDeleteAlert = true
                                            } label: {
                                                Label(settings.t("Delete", "حذف"), systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                selectedExpense = expense
                                            } label: {
                                                Label(settings.t("Edit", "ویرایش"), systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }

                        Section {
                            HStack {
                                Text(settings.t("Total Shown", "مجموع نمایش داده شده"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Text(filteredTotal.formattedAsCurrency)
                                    .font(.subheadline).fontWeight(.bold)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(settings.t("Expenses", "هزینه‌ها"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ),
                prompt: settings.t("Search...", "جستجو...")
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Menu(settings.t("Sort By", "مرتب‌سازی")) {
                            ForEach(ExpenseViewModel.SortOrder.allCases, id: \.rawValue) { order in
                                Button {
                                    viewModel.sortOrder = order
                                } label: {
                                    if viewModel.sortOrder == order {
                                        Label(order.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(order.displayName)
                                    }
                                }
                            }
                        }
                        Menu(settings.t("Time Range", "بازه زمانی")) {
                            ForEach(ExpenseViewModel.DateRange.allCases, id: \.rawValue) { range in
                                Button {
                                    viewModel.selectedDateRange = range
                                } label: {
                                    if viewModel.selectedDateRange == range {
                                        Label(range.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(range.displayName)
                                    }
                                }
                            }
                        }
                        Button(role: .destructive) {
                            viewModel.selectedCategory = nil
                            viewModel.searchText = ""
                            viewModel.selectedDateRange = .thisMonth
                        } label: {
                            Label(settings.t("Clear Filters", "پاک کردن فیلترها"), systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(viewModel.selectedCategory != nil ? .fill : .none)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingAddExpense = true
                        } label: {
                            Label(settings.t("Manual Entry", "ورود دستی"), systemImage: "square.and.pencil")
                        }
                        Button {
                            showingScanner = true
                        } label: {
                            Label(settings.t("Scan Receipt", "اسکن فیش"), systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showingScanner) { ReceiptScannerView() }
            .sheet(item: $selectedExpense) { expense in
                AddExpenseView(editingExpense: expense)
            }
            .alert(settings.t("Delete Expense", "حذف هزینه"),
                   isPresented: $showingDeleteAlert, presenting: expenseToDelete) { expense in
                Button(settings.t("Delete", "حذف"), role: .destructive) { delete(expense) }
                Button(settings.t("Cancel", "انصراف"), role: .cancel) {}
            } message: { expense in
                Text("'\(expense.title)' \(settings.t("will be deleted.", "حذف خواهد شد."))")
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: settings.t("All", "همه"),
                    isSelected: viewModel.selectedCategory == nil
                ) { viewModel.selectedCategory = nil }

                ForEach(ExpenseCategory.allCases) { category in
                    FilterChip(
                        icon: category.icon,
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category,
                        color: category.color
                    ) {
                        viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func sectionHeader(for dateKey: String) -> some View {
        HStack {
            Text(dateKey).font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
            Spacer()
            let dayTotal = (groupedExpenses[dateKey] ?? []).reduce(0) { $0 + $1.amount }
            Text(dayTotal.formattedCompact).font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed

    private var filteredExpenses: [Expense] { viewModel.filteredExpenses(expenses) }
    private var filteredTotal: Double { filteredExpenses.reduce(0) { $0 + $1.amount } }
    private var groupedExpenses: [String: [Expense]] {
        Dictionary(grouping: filteredExpenses) { $0.date.relativeFormatted }
    }

    private func delete(_ expense: Expense) {
        modelContext.delete(expense)
    }
}
