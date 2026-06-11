import SwiftUI
import SwiftData
import PhotosUI

struct AddExpenseView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingExpense: Expense? = nil

    @State private var title = ""
    @State private var amountText = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var date = Date()
    @State private var notes = ""
    @State private var merchant = ""
    @State private var isRecurring = false
    @State private var recurringDays = 30
    @State private var paymentMethod = "Cash"
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var receiptImage: UIImage? = nil
    @State private var showingCategorySuggestion = false
    @State private var suggestedCategory: ExpenseCategory? = nil

    private let paymentMethods = ["Cash", "Card", "Online Transfer", "Digital Wallet"]

    private var isEditing: Bool { editingExpense != nil }
    private var isValidForm: Bool { !title.isEmpty && (Double(amountText) ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                // Amount
                Section {
                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Spacer()
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .frame(maxWidth: 200)
                                .onChange(of: amountText) { suggestCategoryIfNeeded() }
                            Text(settings.t("T", "ت"))
                                .font(.title3).foregroundStyle(.secondary)
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            ForEach([50_000.0, 100_000.0, 200_000.0, 500_000.0], id: \.self) { amount in
                                Button(amount.formattedCompact) {
                                    amountText = "\(Int(amount))"
                                }
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color(.systemBackground))

                // Basic Info
                Section(settings.t("Details", "اطلاعات")) {
                    HStack {
                        Image(systemName: "tag.fill").foregroundStyle(.secondary).frame(width: 24)
                        TextField(settings.t("Expense title", "عنوان هزینه"), text: $title)
                            .onChange(of: title) { suggestCategoryIfNeeded() }
                    }
                    HStack {
                        Image(systemName: "storefront.fill").foregroundStyle(.secondary).frame(width: 24)
                        TextField(settings.t("Merchant (optional)", "نام فروشگاه (اختیاری)"), text: $merchant)
                    }
                    DatePicker(settings.t("Date", "تاریخ"), selection: $date, displayedComponents: [.date])
                }

                // Category
                Section(settings.t("Category", "دسته‌بندی")) {
                    if let suggested = suggestedCategory, showingCategorySuggestion {
                        HStack {
                            Image(systemName: "brain").foregroundStyle(.purple)
                            Text("\(settings.t("AI suggests:", "پیشنهاد AI:")) \(suggested.displayName)")
                                .font(.subheadline).foregroundStyle(.purple)
                            Spacer()
                            Button(settings.t("Apply", "اعمال")) {
                                selectedCategory = suggested
                                showingCategorySuggestion = false
                            }
                            .font(.caption).foregroundStyle(settings.theme.primary)
                        }
                        .padding(.vertical, 4)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                                showingCategorySuggestion = false
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedCategory == category
                                                  ? category.color : category.color.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: category.icon)
                                            .foregroundStyle(selectedCategory == category ? .white : category.color)
                                            .font(.system(size: 18))
                                    }
                                    Text(category.displayName)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Payment
                Section(settings.t("Payment Method", "روش پرداخت")) {
                    Picker(settings.t("Payment", "پرداخت"), selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Recurring
                Section {
                    Toggle(isOn: $isRecurring) {
                        Label(settings.t("Recurring Expense", "هزینه تکراری"), systemImage: "arrow.clockwise")
                    }
                    if isRecurring {
                        Stepper(settings.t("Every \(recurringDays) days", "هر \(recurringDays) روز"),
                                value: $recurringDays, in: 1...365, step: 1)
                        Text(settings.t("e.g. Monthly subscription = 30 days", "مثلاً اشتراک ماهانه = ۳۰ روز"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Notes
                Section(settings.t("Notes", "یادداشت")) {
                    TextField(settings.t("Additional notes...", "توضیحات اضافی..."), text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                // Receipt Photo
                Section(settings.t("Receipt Photo", "تصویر فیش")) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let image = receiptImage {
                            Image(uiImage: image)
                                .resizable().scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label(settings.t("Add Receipt Photo", "افزودن تصویر فیش"),
                                  systemImage: "camera.on.rectangle")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                    }
                    .onChange(of: selectedPhotoItem) {
                        Task {
                            if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                receiptImage = image
                            }
                        }
                    }

                    if receiptImage != nil {
                        Button(role: .destructive) {
                            receiptImage = nil
                            selectedPhotoItem = nil
                        } label: {
                            Label(settings.t("Remove Photo", "حذف تصویر"), systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing
                             ? settings.t("Edit Expense", "ویرایش هزینه")
                             : settings.t("New Expense", "هزینه جدید"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("Cancel", "انصراف")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? settings.t("Save", "ذخیره") : settings.t("Add", "افزودن")) {
                        saveExpense()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidForm)
                }
            }
            .onAppear { loadEditingExpense() }
        }
    }

    private func suggestCategoryIfNeeded() {
        guard !title.isEmpty else { return }
        let suggested = AIService.shared.suggestCategory(for: title, amount: Double(amountText) ?? 0)
        if suggested != .other && suggested != selectedCategory {
            suggestedCategory = suggested
            showingCategorySuggestion = true
        }
    }

    private func loadEditingExpense() {
        guard let expense = editingExpense else { return }
        title = expense.title
        amountText = "\(Int(expense.amount))"
        selectedCategory = expense.category
        date = expense.date
        notes = expense.notes
        merchant = expense.merchant
        isRecurring = expense.isRecurring
        recurringDays = expense.recurringIntervalDays
        paymentMethod = expense.paymentMethod
        if let data = expense.receiptImageData {
            receiptImage = UIImage(data: data)
        }
    }

    private func saveExpense() {
        let amount = Double(amountText) ?? 0
        if let existing = editingExpense {
            existing.title = title
            existing.amount = amount
            existing.category = selectedCategory
            existing.date = date
            existing.notes = notes
            existing.merchant = merchant
            existing.isRecurring = isRecurring
            existing.recurringIntervalDays = recurringDays
            existing.paymentMethod = paymentMethod
            existing.receiptImageData = receiptImage?.jpegData(compressionQuality: 0.7)
        } else {
            let expense = Expense(
                title: title, amount: amount, category: selectedCategory,
                date: date, notes: notes, merchant: merchant,
                isRecurring: isRecurring, recurringIntervalDays: recurringDays,
                paymentMethod: paymentMethod
            )
            expense.receiptImageData = receiptImage?.jpegData(compressionQuality: 0.7)
            modelContext.insert(expense)
        }
    }
}
