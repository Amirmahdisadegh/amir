import Foundation

/// Looks up a scanned barcode in the free Open Food Facts database.
enum OpenFoodFactsService {

    static func lookup(_ barcode: String) async -> FoodAnalysis? {
        let code = barcode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,brands,nutriments,serving_size")
        else { return nil }

        var request = URLRequest(url: url)
        request.setValue("CalSnap/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? Int) == 1,
              let product = json["product"] as? [String: Any]
        else { return nil }

        let nutr = (product["nutriments"] as? [String: Any]) ?? [:]
        var name = (product["product_name"] as? String) ?? ""
        if name.isEmpty { name = (product["brands"] as? String) ?? "Product" }

        // Prefer per-serving values; fall back to per-100g.
        let hasServing = num(nutr["energy-kcal_serving"]) != nil
        let suffix = hasServing ? "_serving" : "_100g"
        let quantity: String = hasServing
            ? ((product["serving_size"] as? String) ?? "1 serving")
            : "100 g"

        let calories = Int((num(nutr["energy-kcal\(suffix)"]) ?? num(nutr["energy-kcal_100g"]) ?? 0).rounded())
        let item = FoodItem(
            name: name,
            quantity: quantity,
            calories: calories,
            proteinGrams: num(nutr["proteins\(suffix)"]) ?? 0,
            carbsGrams: num(nutr["carbohydrates\(suffix)"]) ?? 0,
            fatGrams: num(nutr["fat\(suffix)"]) ?? 0,
            confidence: 1
        )
        return FoodAnalysis(title: name, items: [item],
                            summary: "From Open Food Facts", isEstimateOnly: false)
    }

    private static func num(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) }
        return nil
    }
}
