import Foundation
import UIKit
import AVFoundation

// MARK: - Result types

struct FoodAnalysis: Equatable {
    var title: String
    var items: [FoodItem]
    var summary: String          // a short friendly note from the model
    var isEstimateOnly: Bool     // true when produced by the offline fallback

    var totalCalories: Int { items.reduce(0) { $0 + $1.calories } }
}

enum VisionError: LocalizedError {
    case missingKey
    case noFrames
    case badResponse(String)
    case decoding
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingKey:        return "No Claude API key configured."
        case .noFrames:          return "Could not read frames from the media."
        case .badResponse(let m):return "Unexpected response: \(m)"
        case .decoding:          return "Could not parse the AI response."
        case .http(let c, let m):return "Request failed (\(c)): \(m)"
        }
    }
}

// MARK: - Claude Vision food recognition

/// Sends one or more meal images (or sampled video frames) to Claude and
/// asks for a structured nutrition breakdown. Falls back to a coarse on-device
/// estimate when no API key is present so the app stays usable offline.
final class FoodVisionService {

    /// Vision-capable Claude model. Sonnet 4.6 balances accuracy, speed and cost
    /// for frequent meal photos; swap to claude-opus-4-8 for maximum accuracy.
    static let model = "claude-sonnet-4-6"

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiKey: String?

    init(apiKey: String?) {
        self.apiKey = apiKey
    }

    // MARK: Public entry points

    /// Analyze a single still image of a meal.
    func analyzePhoto(_ image: UIImage, hint: String? = nil) async throws -> FoodAnalysis {
        let data = Self.jpeg(from: image)
        return try await analyze(imageDatas: [data], hint: hint, fromVideo: false)
    }

    /// Analyze a short meal video by sampling representative frames.
    func analyzeVideo(url: URL, hint: String? = nil) async throws -> FoodAnalysis {
        let frames = try await Self.sampleFrames(from: url, maxFrames: 4)
        guard !frames.isEmpty else { throw VisionError.noFrames }
        let datas = frames.map { Self.jpeg(from: $0) }
        return try await analyze(imageDatas: datas, hint: hint, fromVideo: true)
    }

    // MARK: Core request

    private func analyze(imageDatas: [Data], hint: String?, fromVideo: Bool) async throws -> FoodAnalysis {
        guard let apiKey, !apiKey.isEmpty else {
            return OfflineEstimator.estimate(hint: hint)
        }

        var content: [[String: Any]] = imageDatas.map { data in
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": data.base64EncodedString()
                ]
            ]
        }
        content.append(["type": "text", "text": Self.userPrompt(hint: hint, fromVideo: fromVideo)])

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 1024,
            "system": Self.systemPrompt,
            "messages": [["role": "user", "content": content]]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VisionError.badResponse("no http response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown"
            throw VisionError.http(http.statusCode, message)
        }

        let text = try Self.extractText(from: data)
        return try Self.parse(text)
    }

    // MARK: Prompts

    private static let systemPrompt = """
    You are CalSnap's nutrition vision engine. You receive one or more photos \
    (or sampled video frames) of a meal. Identify every distinct food and drink, \
    estimate realistic portion sizes, and return nutrition facts.

    Respond with ONLY a JSON object, no markdown, no commentary, in this exact shape:
    {
      "title": "short meal name",
      "summary": "one friendly sentence about the meal",
      "items": [
        {
          "name": "food name",
          "quantity": "human portion e.g. '1 bowl' or '150 g'",
          "calories": 0,
          "protein_g": 0.0,
          "carbs_g": 0.0,
          "fat_g": 0.0,
          "confidence": 0.0
        }
      ]
    }

    Rules: integers for calories; one decimal for grams; confidence between 0 and 1. \
    If frames show the same meal, count it once. If you cannot tell, give your best \
    estimate rather than refusing. Keep the title under 4 words.
    """

    private static func userPrompt(hint: String?, fromVideo: Bool) -> String {
        var lines = [String]()
        lines.append(fromVideo
            ? "These frames are sampled from a video of one meal. Analyze the meal."
            : "Analyze this meal photo.")
        if let hint, !hint.isEmpty {
            lines.append("User note about the food: \"\(hint)\".")
        }
        lines.append("Return only the JSON object.")
        return lines.joined(separator: " ")
    }

    // MARK: Response parsing

    private static func extractText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw VisionError.decoding
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw VisionError.decoding }
        return text
    }

    private static func parse(_ text: String) throws -> FoodAnalysis {
        // Be forgiving: pull out the first {...} block in case of stray text.
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw VisionError.badResponse(text)
        }
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VisionError.decoding
        }

        let title = (obj["title"] as? String) ?? "Meal"
        let summary = (obj["summary"] as? String) ?? ""
        let rawItems = (obj["items"] as? [[String: Any]]) ?? []
        let items: [FoodItem] = rawItems.map { d in
            FoodItem(
                name: (d["name"] as? String) ?? "Food",
                quantity: (d["quantity"] as? String) ?? "1 serving",
                calories: intValue(d["calories"]),
                proteinGrams: doubleValue(d["protein_g"]),
                carbsGrams: doubleValue(d["carbs_g"]),
                fatGrams: doubleValue(d["fat_g"]),
                confidence: min(max(doubleValue(d["confidence"], default: 0.8), 0), 1)
            )
        }
        return FoodAnalysis(title: title, items: items, summary: summary, isEstimateOnly: false)
    }

    private static func intValue(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d.rounded()) }
        if let s = any as? String, let d = Double(s) { return Int(d.rounded()) }
        return 0
    }

    private static func doubleValue(_ any: Any?, default def: Double = 0) -> Double {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String, let d = Double(s) { return d }
        return def
    }

    // MARK: Media helpers

    private static func jpeg(from image: UIImage, maxDimension: CGFloat = 1024) -> Data {
        let scaled = image.resized(maxDimension: maxDimension)
        return scaled.jpegData(compressionQuality: 0.7) ?? Data()
    }

    /// Evenly samples up to `maxFrames` frames across the video timeline.
    private static func sampleFrames(from url: URL, maxFrames: Int) async throws -> [UIImage] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1024, height: 1024)

        let count = max(1, min(maxFrames, Int(seconds.rounded()) + 1))
        var images: [UIImage] = []
        for i in 0..<count {
            let t = seconds * (Double(i) + 0.5) / Double(count)
            let time = CMTime(seconds: t, preferredTimescale: 600)
            if let cg = try? await generator.image(at: time).image {
                images.append(UIImage(cgImage: cg))
            }
        }
        return images
    }
}
