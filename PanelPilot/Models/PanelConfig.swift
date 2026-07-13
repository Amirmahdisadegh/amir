import Foundation

/// Connection configuration for the 3x-ui panel.
struct PanelConfig: Codable, Equatable {
    var baseURL: String
    var username: String
    var password: String

    /// Pre-configured defaults for the owner's panel. Editable in Settings.
    static let `default` = PanelConfig(
        baseURL: "https://panel.amber-thicket.online:54321/OVm5ec2vkyVvBr5fY3/",
        username: "Amirmahdi",
        password: "@13842005AmS"
    )

    /// Normalised base URL guaranteed to end with a single trailing slash.
    var normalizedBase: String {
        var s = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        // Users often paste the browser address, which ends at the web UI
        // ({base}/panel). Login and the API actually live at {base}, so drop a
        // trailing "/panel" segment if present — the app works either way.
        if s.lowercased().hasSuffix("/panel") {
            s = String(s.dropLast("/panel".count))
            while s.hasSuffix("/") { s.removeLast() }
        }
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
