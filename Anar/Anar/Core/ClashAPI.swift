import Foundation

/// Minimal client for sing-box's built-in Clash API (enabled via the
/// `with_clash_api` build tag + `experimental.clash_api` config). Used for live
/// traffic totals and latency tests.
struct ClashAPI {
    let port: Int

    private var base: String { "http://127.0.0.1:\(port)" }

    struct Totals { var up: Int; var down: Int }

    /// Cumulative upload/download byte totals across all connections.
    func totals() async -> Totals? {
        guard let url = URL(string: "\(base)/connections") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let up = (obj["uploadTotal"] as? NSNumber)?.intValue ?? 0
        let down = (obj["downloadTotal"] as? NSNumber)?.intValue ?? 0
        return Totals(up: up, down: down)
    }

    /// Latency (ms) of the proxy outbound, measured by sing-box itself.
    func delay(tag: String = SingboxConfig.proxyTag,
               testURL: String = "http://www.gstatic.com/generate_204",
               timeoutMs: Int = 5000) async -> Int? {
        let encodedTag = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        let encodedURL = testURL.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? testURL
        guard let url = URL(string: "\(base)/proxies/\(encodedTag)/delay?timeout=\(timeoutMs)&url=\(encodedURL)") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return (obj["delay"] as? NSNumber)?.intValue
    }

    /// True once the API answers — a reliable "core is up" signal.
    func isUp() async -> Bool {
        guard let url = URL(string: "\(base)/version") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=?/:")
        return cs
    }()
}
