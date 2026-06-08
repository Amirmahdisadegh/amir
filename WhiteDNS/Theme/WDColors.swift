import SwiftUI

extension Color {
    static let wdBg         = Color(hex: "0A0C10")!
    static let wdSurface    = Color(hex: "13161D")!
    static let wdSurfaceAlt = Color(hex: "1C2030")!
    static let wdBorder     = Color(hex: "252B3A")!
    static let wdAccent     = Color(hex: "7C6FEA")!
    static let wdSuccess    = Color(hex: "10D98E")!
    static let wdError      = Color(hex: "FF5757")!
    static let wdWarning    = Color(hex: "FFC043")!
    static let wdMuted      = Color(hex: "8B94A8")!
    static let wdInk        = Color.white
}

// Allows .wdXxx shorthand inside .foregroundStyle() / .fill() / .stroke()
extension ShapeStyle where Self == Color {
    static var wdBg:         Color { .wdBg }
    static var wdSurface:    Color { .wdSurface }
    static var wdSurfaceAlt: Color { .wdSurfaceAlt }
    static var wdBorder:     Color { .wdBorder }
    static var wdAccent:     Color { .wdAccent }
    static var wdSuccess:    Color { .wdSuccess }
    static var wdError:      Color { .wdError }
    static var wdWarning:    Color { .wdWarning }
    static var wdMuted:      Color { .wdMuted }
    static var wdInk:        Color { .wdInk }
}
