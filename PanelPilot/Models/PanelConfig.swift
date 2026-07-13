import Foundation

/// Connection configuration for the 3x-ui panel.
struct PanelConfig: Codable, Equatable {
    var baseURL: String
    var username: String
    var password: String
    /// Optional Bearer API token (Settings → Security → API Token in the panel).
    /// When present it is the preferred auth: it works for every /panel/api/*
    /// endpoint and skips the CSRF flow that a cookie session requires.
    var apiToken: String

    init(baseURL: String, username: String, password: String, apiToken: String = "") {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.apiToken = apiToken
    }

    // Decode leniently so configs saved by older builds (without apiToken) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = (try? c.decode(String.self, forKey: .baseURL)) ?? ""
        username = (try? c.decode(String.self, forKey: .username)) ?? ""
        password = (try? c.decode(String.self, forKey: .password)) ?? ""
        apiToken = (try? c.decode(String.self, forKey: .apiToken)) ?? ""
    }

    var usesToken: Bool { !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Pre-configured defaults for the owner's panel. Editable in Settings.
    static let `default` = PanelConfig(
        baseURL: "https://panel.amber-thicket.online:54321/OVm5ec2vkyVvBr5fY3/",
        username: "Amirmahdi",
        password: "@13842005AmS"
    )

    /// Normalised base URL guaranteed to end with a single trailing slash.
    ///
    /// Login and the API live at `{base}` (the secret web-base-path), while the
    /// web UI a user copies from the browser lives under `{base}/panel/...`
    /// (e.g. `/panel/clients`, `/panel/inbounds`). We parse the URL and drop the
    /// `panel` path segment and everything after it, so pasting *any* panel page
    /// URL still resolves the API correctly.
    var normalizedBase: String {
        let raw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if var comps = URLComponents(string: raw), comps.host != nil {
            var segments = comps.path
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
            if let idx = segments.firstIndex(where: { $0.lowercased() == "panel" }) {
                segments = Array(segments.prefix(idx))
            }
            comps.path = segments.isEmpty ? "" : "/" + segments.joined(separator: "/")
            comps.query = nil
            comps.fragment = nil
            if var s = comps.string {
                while s.hasSuffix("/") { s.removeLast() }
                return s + "/"
            }
        }

        // Fallback for strings URLComponents can't parse.
        var s = raw
        while s.hasSuffix("/") { s.removeLast() }
        return s + "/"
    }

    /// Host portion used as the default server address when building connection URIs.
    var host: String {
        URL(string: normalizedBase)?.host ?? ""
    }

    func url(_ path: String) -> URL? {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: normalizedBase + trimmed)
    }
}
