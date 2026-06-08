import SwiftUI
import SwiftData
import PhotosUI
import Vision

struct ReceiptScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var scannedImage: UIImage? = nil
    @State private var isProcessing = false
    @State private var scannedReceipt: ScannedReceipt? = nil
    @State private var showingResult = false
    @State private var showingCamera = false

    // Editable fields from scan result
    @State private var editedTitle = ""
    @State private var editedAmount = ""
    @State private var editedMerchant = ""
    @State private var editedCategory: ExpenseCategory = .other
    @State private var editedDate = Date()
    @State private var editedNotes = ""

    var body: some View {
        NavigationStack {
            if showingResult, let receipt = scannedReceipt {
                resultView(receipt: receipt)
            } else {
                mainScanView
            }
        }
    }

    // MARK: - Main Scan View

    private var mainScanView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Scanner illustration
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.appPrimary.opacity(0.08))
                        .frame(width: 160, height: 200)

                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 64))
                            .foregroundColor(.appPrimary)

                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text(isProcessing ? "در حال پردازش..." : "اسکن فیش")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(isProcessing
                         ? "لطفاً صبر کنید، تصویر در حال تحلیل است"
                         : "تصویر فیش را انتخاب کنید تا اطلاعات\nبه‌صورت خودکار استخراج شود")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                // Camera button
                Button {
                    showingCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("عکس بگیر")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .fontWeight(.semibold)
                }

                // Photo picker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("انتخاب از گالری")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .fontWeight(.semibold)
                }
                .onChange(of: selectedPhotoItem) {
                    Task {
                        if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await processImage(image)
                        }
                    }
                }

                // Manual entry fallback
                Button {
                    dismiss()
                } label: {
                    Text("ورود دستی")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("اسکن فیش")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("بستن") { dismiss() }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                Task { await processImage(image) }
            }
        }
    }

    // MARK: - Result View

    private func resultView(receipt: ScannedReceipt) -> some View {
        Form {
            Section {
                if let image = scannedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: .infinity)
                }
            }

            Section("اطلاعات استخراج‌شده") {
                HStack {
                    Image(systemName: "tag.fill").foregroundColor(.secondary).frame(width: 24)
                    TextField("عنوان", text: $editedTitle)
                }
                HStack {
                    Image(systemName: "storefront.fill").foregroundColor(.secondary).frame(width: 24)
                    TextField("فروشگاه", text: $editedMerchant)
                }
                HStack {
                    Image(systemName: "banknote.fill").foregroundColor(.secondary).frame(width: 24)
                    TextField("مبلغ", text: $editedAmount)
                        .keyboardType(.decimalPad)
                    Text("تومان").foregroundColor(.secondary)
                }
                DatePicker("تاریخ", selection: $editedDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "fa_IR"))
            }

            Section("دسته‌بندی") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(ExpenseCategory.allCases) { cat in
                        Button {
                            editedCategory = cat
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(editedCategory == cat ? cat.color : cat.color.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: cat.icon)
                                        .foregroundColor(editedCategory == cat ? .white : cat.color)
                                        .font(.system(size: 16))
                                }
                                Text(cat.displayName)
                                    .font(.system(size: 9))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("یادداشت") {
                TextField("توضیح اضافی...", text: $editedNotes, axis: .vertical)
                    .lineLimit(2...4)
            }

            if !receipt.items.isEmpty {
                Section("اقلام تشخیص داده شده") {
                    ForEach(receipt.items.prefix(10), id: \.self) { item in
                        Text(item).font(.caption)
                    }
                }
            }

            if !receipt.rawText.isEmpty {
                Section("متن خام فیش") {
                    Text(receipt.rawText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("تایید اطلاعات")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("بازگشت") {
                    showingResult = false
                    scannedReceipt = nil
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("ذخیره") {
                    saveScannedExpense()
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(editedTitle.isEmpty || (Double(editedAmount) ?? 0) == 0)
            }
        }
    }

    // MARK: - Processing

    @MainActor
    private func processImage(_ image: UIImage) async {
        scannedImage = image
        isProcessing = true

        let receipt = await OCRService.shared.scanReceipt(from: image)

        scannedReceipt = receipt
        editedTitle = receipt.merchant.isEmpty ? "هزینه اسکن شده" : receipt.merchant
        editedMerchant = receipt.merchant
        editedAmount = receipt.amount > 0 ? "\(Int(receipt.amount))" : ""
        editedCategory = receipt.suggestedCategory
        editedDate = receipt.date

        if !receipt.items.isEmpty {
            editedNotes = receipt.items.prefix(3).joined(separator: "، ")
        }

        isProcessing = false
        showingResult = true
    }

    private func saveScannedExpense() {
        let expense = Expense(
            title: editedTitle,
            amount: Double(editedAmount) ?? 0,
            category: editedCategory,
            date: editedDate,
            notes: editedNotes,
            merchant: editedMerchant
        )
        expense.receiptImageData = scannedImage?.jpegData(compressionQuality: 0.7)
        modelContext.insert(expense)
    }
}

// MARK: - Camera View (UIViewControllerRepresentable)

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.cameraDevice = .rear
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
