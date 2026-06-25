import Foundation

struct GeoInfo: Equatable {
    let ip: String
    let country: String
    let code: String
}

/// Looks up the current exit IP + country. After connecting, the app's own
/// traffic exits through the tunnel (TUN) or the system SOCKS proxy (proxy
/// mode), so this reports the country you're connected *through*.
enum GeoService {
    static func lookup() async -> GeoInfo? {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: cfg)
        guard let url = URL(string: "http://ip-api.com/json/?fields=status,country,countryCode,query") else { return nil }
        guard let (data, _) = try? await session.data(from: url),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (o["status"] as? String) == "success" else { return nil }
        return GeoInfo(
            ip: o["query"] as? String ?? "",
            country: o["country"] as? String ?? "",
            code: o["countryCode"] as? String ?? ""
        )
    }
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
