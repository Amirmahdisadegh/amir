import SwiftUI
import SwiftData
import PhotosUI
import Vision
import AVFoundation

struct ReceiptScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var scannedImage: UIImage? = nil
    @State private var isProcessing = false
    @State private var scannedReceipt: ScannedReceipt? = nil
    @State private var showingResult = false
    @State private var showingCamera = false
    @State private var showingVideoScanner = false

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
        ZStack {
            LinearGradient(colors: [Color(hex: "#0f0c29") ?? .black, Color(hex: "#24243e") ?? .indigo],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated icon
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 160, height: 180)
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.2), lineWidth: 1))

                        VStack(spacing: 12) {
                            Image(systemName: isProcessing ? "rays" : "doc.text.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, isActive: isProcessing)
                            if isProcessing {
                                ProgressView().progressViewStyle(.circular).tint(.white)
                            }
                        }
                    }

                    VStack(spacing: 8) {
                        Text(isProcessing ? "در حال تحلیل..." : "اسکن فیش")
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                        Text(isProcessing
                             ? "هوش مصنوعی در حال استخراج اطلاعات است"
                             : "تصویر فیش را انتخاب کن یا از دوربین بگیر")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Camera
                    Button { showingCamera = true } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("عکس بگیر")
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .fontWeight(.semibold)
                    }

                    // Live Video Scanner
                    Button { showingVideoScanner = true } label: {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("اسکن زنده از دوربین")
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .fontWeight(.semibold)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }

                    // Photo picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("انتخاب از گالری")
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .fontWeight(.medium)
                    }
                    .onChange(of: selectedPhotoItem) {
                        Task {
                            if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                await processImage(image)
                            }
                        }
                    }

                    Button { dismiss() } label: {
                        Text("ورود دستی")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("اسکن فیش")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("بستن") { dismiss() }
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in Task { await processImage(image) } }
        }
        .sheet(isPresented: $showingVideoScanner) {
            LiveVideoScannerView { image in
                showingVideoScanner = false
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
                        .resizable().scaledToFit()
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
                    TextField("مبلغ", text: $editedAmount).keyboardType(.decimalPad)
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
                                    .font(.system(size: 9)).foregroundColor(.primary).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("یادداشت") {
                TextField("توضیح...", text: $editedNotes, axis: .vertical).lineLimit(2...4)
            }

            if !receipt.items.isEmpty {
                Section("اقلام تشخیص داده شده") {
                    ForEach(receipt.items.prefix(8), id: \.self) { item in
                        Text(item).font(.caption)
                    }
                }
            }
        }
        .navigationTitle("تایید اطلاعات")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("بازگشت") { showingResult = false; scannedReceipt = nil }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("ذخیره") { saveScannedExpense(); dismiss() }
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
        if !receipt.items.isEmpty { editedNotes = receipt.items.prefix(3).joined(separator: "، ") }
        isProcessing = false
        showingResult = true
    }

    private func saveScannedExpense() {
        let expense = Expense(
            title: editedTitle, amount: Double(editedAmount) ?? 0,
            category: editedCategory, date: editedDate, notes: editedNotes, merchant: editedMerchant
        )
        expense.receiptImageData = scannedImage?.jpegData(compressionQuality: 0.7)
        modelContext.insert(expense)
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
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
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Live Video Scanner

struct LiveVideoScannerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> LiveScannerVC {
        let vc = LiveScannerVC()
        vc.onCapture = onCapture
        return vc
    }
    func updateUIViewController(_ vc: LiveScannerVC, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator {}
}

class LiveScannerVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onCapture: ((UIImage) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isProcessing = false
    private var lastProcessTime = Date()
    private var detectedTextLabel: UILabel?
    private var overlayView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func setupCamera() {
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "scanner.queue"))
        session.addOutput(output)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.session.startRunning()
        }
    }

    private func setupOverlay() {
        // Scanning frame
        let frame = UIView()
        frame.layer.borderColor = UIColor.white.cgColor
        frame.layer.borderWidth = 2
        frame.layer.cornerRadius = 12
        frame.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frame)

        NSLayoutConstraint.activate([
            frame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frame.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            frame.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            frame.heightAnchor.constraint(equalToConstant: 200)
        ])

        // Status label
        let label = UILabel()
        label.text = "فیش را داخل کادر بگیرید"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        detectedTextLabel = label

        NSLayoutConstraint.activate([
            label.bottomAnchor.constraint(equalTo: frame.topAnchor, constant: -12),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            label.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Capture button
        let btn = UIButton(type: .system)
        btn.setTitle("📷  ثبت فریم", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        btn.setTitleColor(.black, for: .normal)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 22
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(captureCurrentFrame), for: .touchUpInside)
        view.addSubview(btn)

        NSLayoutConstraint.activate([
            btn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            btn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btn.widthAnchor.constraint(equalToConstant: 200),
            btn.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Close button
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close.tintColor = .white
        close.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(close)

        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    @objc private func captureCurrentFrame() {
        guard let connection = previewLayer?.connection else { return }
        _ = connection  // trigger next frame capture
        isProcessing = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) > 1.5 else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        // Run quick text detection to update status
        let request = VNRecognizeTextRequest { [weak self] req, _ in
            let texts = (req.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
            let hasNumbers = texts.joined().contains(where: { $0.isNumber })
            DispatchQueue.main.async {
                self?.detectedTextLabel?.text = hasNumbers ? "✅ متن تشخیص داده شد — ثبت کنید" : "فیش را داخل کادر بگیرید"
            }
        }
        request.recognitionLevel = .fast
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])

        // If user tapped capture
        if isProcessing {
            isProcessing = false
            DispatchQueue.main.async { [weak self] in
                self?.onCapture?(uiImage)
                self?.dismiss(animated: true)
            }
        }
    }
}
