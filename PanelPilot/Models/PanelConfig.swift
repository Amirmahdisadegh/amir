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
