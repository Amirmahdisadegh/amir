import Foundation

struct GeoInfo: Equatable {
    let ip: String
    let country: String
    let code: String
    let lat: Double
    let lon: Double
}

/// Looks up the exit IP + country + coordinates. In proxy mode the lookup is
/// sent explicitly through the local HTTP proxy; in TUN mode the app's traffic
/// is already tunneled, so a plain request reports the exit country.
enum GeoService {

    static func lookup(httpProxyPort: Int?) async -> GeoInfo? {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 8
        if let port = httpProxyPort {
            cfg.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: true,
                kCFNetworkProxiesHTTPProxy as String: "127.0.0.1",
                kCFNetworkProxiesHTTPPort as String: port,
                "HTTPSEnable": true,
                "HTTPSProxy": "127.0.0.1",
                "HTTPSPort": port,
            ]
        }
        let session = URLSession(configuration: cfg)
        guard let url = URL(string: "http://ip-api.com/json/?fields=status,country,countryCode,query,lat,lon") else { return nil }
        guard let (data, _) = try? await session.data(from: url),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (o["status"] as? String) == "success" else { return nil }
        return GeoInfo(
            ip: o["query"] as? String ?? "",
            country: o["country"] as? String ?? "",
            code: o["countryCode"] as? String ?? "",
            lat: (o["lat"] as? NSNumber)?.doubleValue ?? 0,
            lon: (o["lon"] as? NSNumber)?.doubleValue ?? 0
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
