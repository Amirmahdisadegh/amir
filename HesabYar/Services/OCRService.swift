import Vision
import UIKit
import Foundation

// Offline receipt OCR using Apple Vision framework
final class OCRService {
    static let shared = OCRService()
    private init() {}

    func scanReceipt(from image: UIImage) async -> ScannedReceipt {
        guard let cgImage = image.cgImage else { return ScannedReceipt() }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fa", "ar", "en"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        let observations = request.results ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        let fullText = lines.joined(separator: "\n")

        return parseReceiptText(fullText, lines: lines)
    }

    private func parseReceiptText(_ fullText: String, lines: [String]) -> ScannedReceipt {
        var receipt = ScannedReceipt()
        receipt.rawText = fullText

        receipt.merchant = extractMerchant(from: lines)
        receipt.amount = extractAmount(from: lines)
        receipt.date = extractDate(from: lines) ?? Date()
        receipt.items = extractItems(from: lines)
        receipt.suggestedCategory = guessCategory(from: fullText)

        return receipt
    }

    private func extractMerchant(from lines: [String]) -> String {
        // Merchant is usually in the first 3 lines
        let candidates = Array(lines.prefix(3))
        return candidates.first(where: { $0.count > 2 && !isNumericLine($0) }) ?? ""
    }

    private func extractAmount(from lines: [String]) -> Double {
        let amountPatterns = [
            "جمع کل[:\\s]*([\\d,،]+)",
            "مبلغ[:\\s]*([\\d,،]+)",
            "total[:\\s]*([\\d,،\\.]+)",
            "([\\d,،]{4,})",
        ]

        for pattern in amountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: lines.joined(separator: " "),
                                             range: NSRange(lines.joined(separator: " ").startIndex..., in: lines.joined(separator: " "))) {
                let joined = lines.joined(separator: " ")
                if let range = Range(match.range(at: 1), in: joined) {
                    let numStr = String(joined[range])
                        .replacingOccurrences(of: ",", with: "")
                        .replacingOccurrences(of: "،", with: "")
                    if let value = Double(numStr), value > 0 {
                        return value
                    }
                }
            }
        }

        // Fall back: find the largest number in the text
        var maxAmount = 0.0
        for line in lines {
            let digits = line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let val = Double(digits), val > maxAmount, val < 1_000_000_000 {
                maxAmount = val
            }
        }
        return maxAmount
    }

    private func extractDate(from lines: [String]) -> Date? {
        let datePatterns = [
            "(\\d{4})[/\\-](\\d{1,2})[/\\-](\\d{1,2})",
            "(\\d{1,2})[/\\-](\\d{1,2})[/\\-](\\d{4})",
            "(\\d{1,2})\\s+([\\u0600-\\u06FF]+)\\s+(\\d{4})",
        ]

        let joined = lines.joined(separator: " ")
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: joined, range: NSRange(joined.startIndex..., in: joined)) != nil {
                // Try to parse the date — simplified to just return today if we can't parse exact
                return Date()
            }
        }
        return nil
    }

    private func extractItems(from lines: [String]) -> [String] {
        lines.filter { line in
            !isNumericLine(line) && line.count > 3 && !isTotalLine(line)
        }
    }

    private func isNumericLine(_ line: String) -> Bool {
        let numericChars = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ",،. "))
        return line.unicodeScalars.allSatisfy { numericChars.contains($0) }
    }

    private func isTotalLine(_ line: String) -> Bool {
        let totalKeywords = ["جمع", "total", "مبلغ", "تخفیف", "مالیات", "tax"]
        return totalKeywords.contains { line.lowercased().contains($0) }
    }

    // Offline AI category guessing based on keywords
    func guessCategory(from text: String) -> ExpenseCategory {
        let lowercased = text.lowercased()
        var scores: [ExpenseCategory: Int] = [:]

        for category in ExpenseCategory.allCases {
            let matchCount = category.keywords.filter { lowercased.contains($0) }.count
            if matchCount > 0 {
                scores[category] = matchCount
            }
        }

        return scores.max(by: { $0.value < $1.value })?.key ?? .other
    }
}
