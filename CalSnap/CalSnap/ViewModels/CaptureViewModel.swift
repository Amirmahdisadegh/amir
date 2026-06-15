import SwiftUI
import UIKit
import Observation
import AVFoundation

/// Drives the capture → analyze → review flow.
@Observable
final class CaptureViewModel {

    enum Phase: Equatable {
        case choosing
        case analyzing
        case review
        case failed(String)
    }

    var phase: Phase = .choosing
    var hint: String = ""

    // Captured media preview.
    var previewImage: UIImage?
    private var pickedMedia: PickedMedia?

    // Editable result.
    var title: String = ""
    var items: [FoodItem] = []
    var summary: String = ""
    var isEstimateOnly = false
    var meal: MealType = .suggested()

    var totalCalories: Int { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.proteinGrams } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbsGrams } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fatGrams } }

    func set(media: PickedMedia) {
        pickedMedia = media
        if case let .image(img) = media { previewImage = img }
    }

    @MainActor
    func analyze(provider: AIProvider, apiKey: String?, model: String) async {
        guard let pickedMedia else { return }
        phase = .analyzing
        let service = FoodVisionService(provider: provider, apiKey: apiKey, model: model)
        do {
            let result: FoodAnalysis
            switch pickedMedia {
            case .image(let image):
                result = try await service.analyzePhoto(image, hint: hint.isEmpty ? nil : hint)
            case .video(let url):
                if previewImage == nil { previewImage = try? await Self.thumbnail(url) }
                result = try await service.analyzeVideo(url: url, hint: hint.isEmpty ? nil : hint)
            }
            apply(result)
            phase = .review
            Haptics.success()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func analyzeBarcode(_ code: String) async {
        phase = .analyzing
        previewImage = nil
        if let result = await OpenFoodFactsService.lookup(code) {
            apply(result)
            phase = .review
            Haptics.success()
        } else {
            phase = .failed("No product found for this barcode. Try a photo or manual search.")
        }
    }

    private func apply(_ result: FoodAnalysis) {
        title = result.title
        items = result.items
        summary = result.summary
        isEstimateOnly = result.isEstimateOnly
    }

    func addBlankItem() {
        items.append(FoodItem(name: "", quantity: "1 serving",
                              calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0,
                              confidence: 1))
    }

    func makeEntry() -> FoodEntry {
        let imageData = previewImage?.resized(maxDimension: 800).jpegData(compressionQuality: 0.6)
        return FoodEntry(title: title.isEmpty ? "Meal" : title,
                         meal: meal,
                         items: items,
                         imageData: imageData,
                         note: hint)
    }

    private static func thumbnail(_ url: URL) async throws -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        let cg = try await gen.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)).image
        return UIImage(cgImage: cg)
    }
}
