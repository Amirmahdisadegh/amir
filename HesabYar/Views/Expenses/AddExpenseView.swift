import SwiftUI
import SwiftData
import PhotosUI

struct AddExpenseView: View {
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
    @State private var paymentMethod = "نقدی"
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var receiptImage: UIImage? = nil
    @State private var showingCategorySuggestion = false
    @State private var suggestedCategory: ExpenseCategory? = nil

    private let paymentMethods = ["نقدی", "کارت بانکی", "انتقال آنلاین", "کیف پول دیجیتال"]

    var isEditing: Bool { editingExpense != nil }
    var isValidForm: Bool { !title.isEmpty && (Double(amountText) ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                // Amount section
                Section {
                    VStack(spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Spacer()
                            TextField("۰", text: $amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .frame(maxWidth: 200)
                                .onChange(of: amountText) {
                                    if !amountText.isEmpty {
                                        let suggested = AIService.shared.suggestCategory(
                                            for: title, amount: Double(amountText) ?? 0
                                        )
                                        if suggested != .other && suggested != selectedCategory {
                                            suggestedCategory = suggested
                                        }
                                    }
                                }
                            Text("تومان")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        // Quick amount buttons
                        HStack(spacing: 8) {
                            ForEach([50_000.0, 100_000.0, 200_000.0, 500_000.0], id: \.self) { amount in
                                Button(amount.formattedCompact) {
                                    amountText = "\(Int(amount))"
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color(.systemBackground))

                // Basic info
                Section("اطلاعات") {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        TextField("عنوان هزینه", text: $title)
                            .onChange(of: title) {
                                if !title.isEmpty {
                                    let suggested = AIService.shared.suggestCategory(
                                        for: title, amount: Double(amountText) ?? 0
                                    )
                                    if suggested != .other && suggested != selectedCategory {
                                        suggestedCategory = suggested
                                        showingCategorySuggestion = true
                                    }
                                }
                            }
                    }

                    HStack {
                        Image(systemName: "storefront.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        TextField("نام فروشگاه (اختیاری)", text: $merchant)
                    }

                    DatePicker("تاریخ", selection: $date, displayedComponents: [.date])
                        .environment(\.locale, Locale(identifier: "fa_IR"))
                }

                // Category
                Section("دسته‌بندی") {
                    if let suggested = suggestedCategory, showingCategorySuggestion {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundColor(.purple)
                            Text("پیشنهاد AI: \(suggested.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                            Spacer()
                            Button("اعمال") {
                                selectedCategory = suggested
                                showingCategorySuggestion = false
                            }
                            .font(.caption)
                            .foregroundColor(.appPrimary)
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
                                                  ? category.color
                                                  : category.color.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: category.icon)
                                            .foregroundColor(selectedCategory == category ? .white : category.color)
                                            .font(.system(size: 18))
                                    }
                                    Text(category.displayName)
                                        .font(.system(size: 9))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Payment method
                Section("روش پرداخت") {
                    Picker("روش پرداخت", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Recurring
                Section {
                    Toggle(isOn: $isRecurring) {
                        Label("هزینه تکراری", systemImage: "arrow.clockwise")
                    }
                    if isRecurring {
                        Stepper("هر \(recurringDays) روز", value: $recurringDays, in: 1...365, step: 1)
                        Text("مثلاً اشتراک ماهانه = ۳۰ روز")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Notes
                Section("یادداشت") {
                    TextField("توضیحات اضافی...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                // Receipt photo
                Section("تصویر فیش") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let image = receiptImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("افزودن تصویر فیش", systemImage: "camera.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
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
                            Label("حذف تصویر", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "ویرایش هزینه" : "هزینه جدید")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("انصراف") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "ذخیره" : "افزودن") {
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
                title: title,
                amount: amount,
                category: selectedCategory,
                date: date,
                notes: notes,
                merchant: merchant,
                isRecurring: isRecurring,
                recurringIntervalDays: recurringDays,
                paymentMethod: paymentMethod
            )
            expense.receiptImageData = receiptImage?.jpegData(compressionQuality: 0.7)
            modelContext.insert(expense)
        }
    }
}
