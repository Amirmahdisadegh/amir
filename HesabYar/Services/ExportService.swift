import Foundation
import UIKit
import PDFKit

final class ExportService {
    static let shared = ExportService()
    private init() {}

    // MARK: - CSV Export

    func exportToCSV(expenses: [Expense]) -> URL? {
        var csvContent = "تاریخ,عنوان,مبلغ,دسته‌بندی,فروشگاه,یادداشت,روش پرداخت\n"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fa_IR")
        dateFormatter.dateFormat = "yyyy/MM/dd"

        for expense in expenses.sorted(by: { $0.date > $1.date }) {
            let row = [
                dateFormatter.string(from: expense.date),
                expense.title,
                String(format: "%.0f", expense.amount),
                expense.category.displayName,
                expense.merchant,
                expense.notes,
                expense.paymentMethod
            ].map { "\"\($0)\"" }.joined(separator: ",")
            csvContent += row + "\n"
        }

        let fileName = "hesabyar_export_\(Date().timeIntervalSince1970).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvContent.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - PDF Report

    func exportToPDF(expenses: [Expense], month: Int, year: Int) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "حسابیار",
            kCGPDFContextAuthor: "HesabYar App",
            kCGPDFContextTitle: "گزارش مالی ماهانه"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        let monthlyExpenses = expenses.filter {
            let cal = Calendar.current
            return cal.component(.month, from: $0.date) == month &&
                   cal.component(.year, from: $0.date) == year
        }

        let totalSpent = monthlyExpenses.reduce(0) { $0 + $1.amount }
        var categoryTotals: [ExpenseCategory: Double] = [:]
        for expense in monthlyExpenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }

        let data = renderer.pdfData { context in
            context.beginPage()
            let ctx = context.cgContext

            // Background
            ctx.setFillColor(UIColor.systemBackground.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            "گزارش مالی ماهانه".draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

            // Total
            let totalAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let formatted = NumberFormatter()
            formatted.numberStyle = .decimal
            let totalStr = "مجموع هزینه‌ها: \(formatted.string(from: NSNumber(value: totalSpent)) ?? "") تومان"
            totalStr.draw(at: CGPoint(x: 40, y: 80), withAttributes: totalAttrs)

            // Category breakdown
            var yPos: CGFloat = 130
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
            "بر اساس دسته‌بندی:".draw(at: CGPoint(x: 40, y: yPos), withAttributes: headerAttrs)
            yPos += 30

            for (cat, amount) in categoryTotals.sorted(by: { $0.value > $1.value }) {
                let lineAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.label
                ]
                let pct = totalSpent > 0 ? Int((amount / totalSpent) * 100) : 0
                let line = "\(cat.displayName): \(formatted.string(from: NSNumber(value: amount)) ?? "") تومان (\(pct)%)"
                line.draw(at: CGPoint(x: 60, y: yPos), withAttributes: lineAttrs)
                yPos += 22
            }

            // Transactions
            yPos += 20
            "تراکنش‌ها:".draw(at: CGPoint(x: 40, y: yPos), withAttributes: headerAttrs)
            yPos += 30

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd"

            for expense in monthlyExpenses.sorted(by: { $0.date > $1.date }) {
                if yPos > pageHeight - 80 {
                    context.beginPage()
                    yPos = 40
                }
                let lineAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.label
                ]
                let line = "\(dateFormatter.string(from: expense.date))  \(expense.title)  \(formatted.string(from: NSNumber(value: expense.amount)) ?? "") تومان"
                line.draw(at: CGPoint(x: 40, y: yPos), withAttributes: lineAttrs)
                yPos += 20
            }
        }

        let fileName = "hesabyar_report_\(year)_\(month).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
