import SwiftUI
import SwiftData

struct DebtTrackerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var debts: [Debt]
    @State private var showingAddDebt = false
    @State private var selectedTab = 0
    @State private var showPaid = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary banner
                summaryBanner

                // Tab selector
                Picker("نوع بدهی", selection: $selectedTab) {
                    Text("باید بگیرم").tag(0)
                    Text("باید بدم").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // List
                if currentList.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: selectedTab == 0 ? "arrow.down.circle" : "arrow.up.circle",
                        title: selectedTab == 0 ? "بدهی دریافتنی ندارید" : "بدهی پرداختنی ندارید",
                        subtitle: "بدهی جدید اضافه کنید",
                        action: { showingAddDebt = true },
                        actionTitle: "افزودن بدهی"
                    )
                    Spacer()
                } else {
                    List {
                        Section {
                            Toggle("نمایش تسویه‌شده‌ها", isOn: $showPaid)
                        }

                        ForEach(currentList, id: \.id) { debt in
                            DebtRow(debt: debt)
                                .swipeActions(edge: .leading) {
                                    if !debt.isPaid {
                                        Button {
                                            markAsPaid(debt)
                                        } label: {
                                            Label("تسویه", systemImage: "checkmark.circle")
                                        }
                                        .tint(.green)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(debt)
                                    } label: {
                                        Label("حذف", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.t("Debts", "مدیریت بدهی‌ها"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddDebt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDebt) {
                AddDebtView()
            }
        }
    }

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                    Text("دریافتنی")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(totalOwedToMe.formattedCompact)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("تومان")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.red)
                    Text("پرداختنی")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(totalIOwe.formattedCompact)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                Text("تومان")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "equal.circle.fill")
                        .foregroundColor(netBalance >= 0 ? .green : .red)
                    Text("خالص")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(abs(netBalance).formattedCompact)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(netBalance >= 0 ? .green : .red)
                Text(netBalance >= 0 ? "بستانکار" : "بدهکار")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var currentList: [Debt] {
        debts
            .filter { $0.isOwedToMe == (selectedTab == 0) }
            .filter { showPaid ? true : !$0.isPaid }
            .sorted { !$0.isPaid && $1.isPaid || $0.date > $1.date }
    }

    private var totalOwedToMe: Double {
        debts.filter { $0.isOwedToMe && !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    private var totalIOwe: Double {
        debts.filter { !$0.isOwedToMe && !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    private var netBalance: Double { totalOwedToMe - totalIOwe }

    private func markAsPaid(_ debt: Debt) {
        debt.isPaid = true
        debt.paidDate = Date()
    }
}

// MARK: - Debt Row

struct DebtRow: View {
    let debt: Debt

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(debt.isPaid ? Color.gray.opacity(0.15) :
                          debt.isOwedToMe ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: debt.isPaid ? "checkmark.circle.fill" :
                      debt.isOwedToMe ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundColor(debt.isPaid ? .gray :
                                     debt.isOwedToMe ? .green : .red)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(debt.personName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if debt.isPaid {
                        Text("تسویه")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                    if debt.isOverdue {
                        Text("سررسید گذشته")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                    }
                }

                Text(debt.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let days = debt.remainingDays, !debt.isPaid {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(days < 0 ? "\(abs(days)) روز تاخیر" :
                             days == 0 ? "امروز سررسید" : "\(days) روز مانده")
                            .font(.caption)
                    }
                    .foregroundColor(days < 0 ? .red : days <= 3 ? .orange : .secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(debt.amount.formattedCompact)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(debt.isPaid ? .secondary :
                                     debt.isOwedToMe ? .green : .red)
                Text("تومان")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(debt.isPaid ? 0.6 : 1.0)
    }
}

// MARK: - Add Debt View

struct AddDebtView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amountText = ""
    @State private var personName = ""
    @State private var isOwedToMe = true
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86400 * 30)
    @State private var notes = ""
    @State private var reminderEnabled = false

    var isValid: Bool { !title.isEmpty && !personName.isEmpty && (Double(amountText) ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("نوع بدهی") {
                    Picker("نوع", selection: $isOwedToMe) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill").foregroundColor(.green)
                            Text("باید بگیرم")
                        }.tag(true)
                        HStack {
                            Image(systemName: "arrow.up.circle.fill").foregroundColor(.red)
                            Text("باید بدم")
                        }.tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("اطلاعات") {
                    HStack {
                        Image(systemName: "person.fill").foregroundColor(.secondary).frame(width: 24)
                        TextField("نام طرف حساب", text: $personName)
                    }
                    HStack {
                        Image(systemName: "tag.fill").foregroundColor(.secondary).frame(width: 24)
                        TextField("موضوع (مثلاً قرض، قبض، ...)", text: $title)
                    }
                    HStack {
                        Image(systemName: "banknote.fill").foregroundColor(.secondary).frame(width: 24)
                        TextField("مبلغ", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text("تومان").foregroundColor(.secondary)
                    }
                }

                Section("سررسید") {
                    Toggle("تاریخ سررسید دارد", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("سررسید", selection: $dueDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "fa_IR"))
                        Toggle("یادآوری", isOn: $reminderEnabled)
                    }
                }

                Section("یادداشت") {
                    TextField("توضیحات...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("بدهی جدید")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("انصراف") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("افزودن") { save(); dismiss() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let debt = Debt(
            title: title,
            amount: Double(amountText) ?? 0,
            isOwedToMe: isOwedToMe,
            personName: personName,
            dueDate: hasDueDate ? dueDate : nil,
            notes: notes,
            reminderEnabled: reminderEnabled
        )
        modelContext.insert(debt)
    }
}
