import Foundation

struct GeoInfo: Equatable {
    let ip: String
    let country: String
    let code: String
    let lat: Double
    let lon: Double
}

/// Resolves the exit IP + country + coordinates. After connecting, the app's
/// own requests are tunneled (TUN) or sent via the system proxy (proxy mode),
/// so this reports the country you're connected *through*. Tries several
/// providers for reliability.
enum GeoService {

    private static let providers = [
        "https://ipwho.is/",
        "https://ipapi.co/json/",
        "https://api.ip.sb/geoip",
    ]

    /// Returns the exit info, or nil with a short diagnostic string.
    static func lookup() async -> (GeoInfo?, String) {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: cfg)

        var lastError = "no response"
        for provider in providers {
            guard let url = URL(string: provider) else { continue }
            do {
                let (data, _) = try await session.data(from: url)
                if let info = parse(data) { return (info, provider) }
                lastError = "unparsable from \(host(provider))"
            } catch {
                lastError = "\(host(provider)): \(error.localizedDescription)"
            }
        }
        return (nil, lastError)
    }

    private static func parse(_ data: Data) -> GeoInfo? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let ip = (o["ip"] as? String) ?? (o["query"] as? String) ?? ""
        let country = (o["country"] as? String) ?? (o["country_name"] as? String) ?? ""
        let code = (o["country_code"] as? String) ?? (o["countryCode"] as? String) ?? ""
        let lat = num(o["latitude"]) ?? num(o["lat"]) ?? 0
        let lon = num(o["longitude"]) ?? num(o["lon"]) ?? 0
        guard !country.isEmpty || !ip.isEmpty else { return nil }
        return GeoInfo(ip: ip, country: country, code: code, lat: lat, lon: lon)
    }

    private static func num(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }

    private static func host(_ s: String) -> String { URL(string: s)?.host ?? s }
}

/// Converts a 2-letter country code into its flag emoji.
func flagEmoji(_ code: String) -> String {
    guard code.count == 2 else { return "🏳️" }
    let base: UInt32 = 127397
    var scalars = String.UnicodeScalarView()
    for v in code.uppercased().unicodeScalars {
        guard let s = UnicodeScalar(base + v.value) else { return "🏳️" }
        scalars.append(s)
    }
    return String(scalars)
}
