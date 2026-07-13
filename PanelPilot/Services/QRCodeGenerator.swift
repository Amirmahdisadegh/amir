import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// Renders QR codes locally with CoreImage — no network required.
enum QRCodeGenerator {
    private static let context = CIContext()

    static func image(from string: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// SwiftUI wrapper that renders a crisp QR code on a white rounded card.
struct QRCodeView: View {
    let content: String
    var size: CGFloat = 220

    var body: some View {
        Group {
            if let image = QRCodeGenerator.image(from: content) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay(Image(systemName: "qrcode").font(.largeTitle))
            }
        }
    }
}
