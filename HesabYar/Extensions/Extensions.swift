import SwiftUI
import Foundation

extension Double {
    var formattedAsCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fa_IR")
        return (formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))") + " تومان"
    }

    var formattedCompact: String {
        if self >= 1_000_000_000 {
            return String(format: "%.1f میلیارد", self / 1_000_000_000)
        } else if self >= 1_000_000 {
            return String(format: "%.1f میلیون", self / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.0f هزار", self / 1_000)
        }
        return String(format: "%.0f", self)
    }
}

extension Date {
    var farsiFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fa_IR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var farsiShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fa_IR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }

    var relativeFormatted: String {
        if isToday { return "امروز" }
        if isYesterday { return "دیروز" }
        return farsiFormatted
    }
}

extension Color {
    static var cardBackground: Color { Color(.secondarySystemBackground) }
    static var appPrimary: Color { Color(red: 0.2, green: 0.6, blue: 0.9) }
    static var appAccent: Color { Color(red: 0.1, green: 0.8, blue: 0.5) }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func shimmer() -> some View {
        self.redacted(reason: .placeholder)
    }
}
