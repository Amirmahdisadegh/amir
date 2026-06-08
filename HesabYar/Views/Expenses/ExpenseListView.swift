import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var viewModel = ExpenseViewModel()
    @State private var showingAddExpense = false
    @State private var showingScanner = false
    @State private var selectedExpense: Expense? = nil
    @State private var showingDeleteAlert = false
    @State private var expenseToDelete: Expense? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                if filteredExpenses.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: viewModel.searchText.isEmpty ? "receipt" : "magnifyingglass",
                        title: viewModel.searchText.isEmpty ? "هیچ هزینه‌ای ثبت نشده" : "نتیجه‌ای یافت نشد",
                        subtitle: viewModel.searchText.isEmpty
                            ? "اولین هزینه‌ات رو اضافه کن"
                            : "جستجوی دیگری امتحان کن",
                        action: viewModel.searchText.isEmpty ? { showingAddExpense = true } : nil,
                        actionTitle: "افزودن هزینه"
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
                                                Label("حذف", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                selectedExpense = expense
                                            } label: {
                                                Label("ویرایش", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }

                        // Total footer
                        Section {
                            HStack {
                                Text("مجموع نمایش داده شده")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(filteredTotal.formattedAsCurrency)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("هزینه‌ها")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "جستجو...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Menu("مرتب‌سازی") {
                            ForEach(ExpenseViewModel.SortOrder.allCases, id: \.rawValue) { order in
                                Button {
                                    viewModel.sortOrder = order
                                } label: {
                                    if viewModel.sortOrder == order {
                                        Label(order.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(order.rawValue)
                                    }
                                }
                            }
                        }
                        Menu("بازه زمانی") {
                            ForEach(ExpenseViewModel.DateRange.allCases, id: \.rawValue) { range in
                                Button {
                                    viewModel.selectedDateRange = range
                                } label: {
                                    if viewModel.selectedDateRange == range {
                                        Label(range.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(range.rawValue)
                                    }
                                }
                            }
                        }
                        Button(role: .destructive) {
                            viewModel.selectedCategory = nil
                            viewModel.searchText = ""
                            viewModel.selectedDateRange = .thisMonth
                        } label: {
                            Label("پاک کردن فیلترها", systemImage: "xmark.circle")
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
                            Label("ورود دستی", systemImage: "square.and.pencil")
                        }
                        Button {
                            showingScanner = true
                        } label: {
                            Label("اسکن فیش", systemImage: "camera.viewfinder")
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
            .alert("حذف هزینه", isPresented: $showingDeleteAlert, presenting: expenseToDelete) { expense in
                Button("حذف", role: .destructive) { delete(expense) }
                Button("انصراف", role: .cancel) {}
            } message: { expense in
                Text("'\(expense.title)' حذف خواهد شد.")
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "همه",
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
            Text(dateKey)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
            let dayTotal = (groupedExpenses[dateKey] ?? []).reduce(0) { $0 + $1.amount }
            Text(dayTotal.formattedCompact)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Computed

    private var filteredExpenses: [Expense] { viewModel.filteredExpenses(expenses) }
    private var filteredTotal: Double { filteredExpenses.reduce(0) { $0 + $1.amount } }

    private var groupedExpenses: [String: [Expense]] {
        Dictionary(grouping: filteredExpenses) { expense in
            expense.date.relativeFormatted
        }
    }

    private func delete(_ expense: Expense) {
        modelContext.delete(expense)
    }
}

