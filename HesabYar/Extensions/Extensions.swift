import SwiftUI
import Foundation

// MARK: - Double Formatting

extension Double {
    var formattedAsCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fa_IR")
        return (formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))") + " تومان"
    }

    var formattedCompact: String {
        if self >= 1_000_000_000 { return String(format: "%.1f میلیارد", self / 1_000_000_000) }
        if self >= 1_000_000     { return String(format: "%.1f میلیون", self / 1_000_000) }
        if self >= 1_000         { return String(format: "%.0f هزار", self / 1_000) }
        return String(format: "%.0f", self)
    }
}

// MARK: - Date Formatting

extension Date {
    var farsiFormatted: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fa_IR")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }

    var farsiShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fa_IR")
        f.dateFormat = "d MMM"
        return f.string(from: self)
    }

    var relativeFormatted: String {
        if Calendar.current.isDateInToday(self) { return "امروز" }
        if Calendar.current.isDateInYesterday(self) { return "دیروز" }
        return farsiFormatted
    }
}

// MARK: - Colors

extension Color {
    static var cardBackground: Color { Color(.secondarySystemBackground) }
    static var appPrimary:     Color { Color(red: 0.2, green: 0.6, blue: 0.9) }
    static var appAccent:      Color { Color(red: 0.1, green: 0.8, blue: 0.5) }
    static var glassWhite:     Color { Color.white.opacity(0.12) }
}

// MARK: - View Helpers

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func glassCard(cornerRadius: CGFloat = 20, border: Bool = true) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, border: border))
    }

    func darkGlassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}
