import SwiftUI
import UIKit

/// One selectable home-screen icon.
struct AppIconOption: Identifiable {
    /// `nil` alternateName means the primary icon.
    let alternateName: String?
    let name: String
    let colors: [Color]

    var id: String { alternateName ?? "default" }

    static let all: [AppIconOption] = [
        AppIconOption(alternateName: nil, name: "Blue",
                      colors: [Color(hex: 0x7CC4FF), Color(hex: 0x1D6FD6)]),
        AppIconOption(alternateName: "Violet", name: "Violet",
                      colors: [Color(hex: 0xC4B5FD), Color(hex: 0x6D28D9)]),
        AppIconOption(alternateName: "Orange", name: "Orange",
                      colors: [Color(hex: 0xFFB088), Color(hex: 0xE0552C)]),
        AppIconOption(alternateName: "Graphite", name: "Graphite",
                      colors: [Color(hex: 0x3A4150), Color(hex: 0x12161E)]),
    ]
}

enum AppIconManager {
    /// Identifier of the current icon ("default" or the alternate name).
    static var currentID: String {
        UIApplication.shared.alternateIconName ?? "default"
    }

    static var supported: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static func set(_ alternateName: String?) {
        guard supported else { return }
        // Avoid the system prompt when nothing changes.
        guard UIApplication.shared.alternateIconName != alternateName else { return }
        UIApplication.shared.setAlternateIconName(alternateName) { _ in }
    }
}
