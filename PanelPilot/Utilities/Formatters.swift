import Foundation
import SwiftUI

/// Shared formatting helpers with correct Persian-digit and locale handling.
enum Fmt {

    /// Whether the app is currently displaying Persian, used for digit conversion.
    static var isPersian: Bool {
        LocalizationManager.shared.effectiveLanguage == .persian
    }

    private static let latinToPersian: [Character: Character] = [
        "0": "۰", "1": "۱", "2": "۲", "3": "۳", "4": "۴",
        "5": "۵", "6": "۶", "7": "۷", "8": "۸", "9": "۹"
    ]

    /// Convert Latin digits to Persian digits when the UI language is Persian.
    static func digits(_ string: String) -> String {
        guard isPersian else { return string }
        return String(string.map { latinToPersian[$0] ?? $0 })
    }

    // MARK: - Bytes

    static func bytes(_ value: Int64) -> String {
        guard value > 0 else { return digits("0 B") }
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var v = Double(value)
        var idx = 0
        while v >= 1024 && idx < units.count - 1 { v /= 1024; idx += 1 }
        let str = idx == 0 ? String(format: "%.0f %@", v, units[idx])
                           : String(format: "%.2f %@", v, units[idx])
        return digits(str)
    }

    /// Bytes-per-second, e.g. "8.60 MB/s".
    static func speed(_ bytesPerSec: Int64) -> String {
        return digits(bytes(bytesPerSec) + "/s")
    }

    static func percent(_ fraction: Double) -> String {
        digits(String(format: "%.0f%%", min(max(fraction, 0), 1) * 100))
    }

    // MARK: - Traffic limit

    /// Format a used/limit pair, treating limit == 0 as unlimited.
    static func trafficUsage(used: Int64, limit: Int64) -> String {
        if limit <= 0 {
            return "\(bytes(used)) / \("common.unlimited".loc)"
        }
        return "\(bytes(used)) / \(bytes(limit))"
    }

    static func trafficFraction(used: Int64, limit: Int64) -> Double {
        guard limit > 0 else { return 0 }
        return min(Double(used) / Double(limit), 1)
    }

    // MARK: - Dates & expiry

    /// Days remaining until an ms-epoch expiry. Negative == expired. nil == never.
    static func daysRemaining(expiryMs: Int64) -> Int? {
        guard expiryMs > 0 else { return nil }
        let expiry = Date(timeIntervalSince1970: Double(expiryMs) / 1000)
        let seconds = expiry.timeIntervalSinceNow
        return Int(floor(seconds / 86_400))
    }

    static func expiryLabel(expiryMs: Int64) -> String {
        guard let days = daysRemaining(expiryMs: expiryMs) else {
            return "common.never".loc
        }
        if days < 0 { return "client.expired".loc }
        if days == 0 { return "client.expires_today".loc }
        return digits(String(format: "client.days_left".loc, days))
    }

    static func date(_ ms: Int64) -> String {
        guard ms > 0 else { return "common.never".loc }
        let date = Date(timeIntervalSince1970: Double(ms) / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isPersian ? "fa_IR" : "en_US")
        formatter.calendar = isPersian ? Calendar(identifier: .persian) : Calendar(identifier: .gregorian)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// "Updated 2m ago" style relative timestamp.
    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: isPersian ? "fa_IR" : "en_US")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func uptime(_ seconds: Int64) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        parts.append("\(minutes)m")
        return digits(parts.joined(separator: " "))
    }

    static func count(_ n: Int) -> String { digits(String(n)) }
}
