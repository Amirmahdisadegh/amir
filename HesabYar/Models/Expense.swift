import SwiftData
import SwiftUI
import Foundation

// MARK: - Category

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "food"
    case subscriptions = "subscriptions"
    case transport = "transport"
    case entertainment = "entertainment"
    case health = "health"
    case shopping = "shopping"
    case utilities = "utilities"
    case education = "education"
    case travel = "travel"
    case restaurant = "restaurant"
    case grocery = "grocery"
    case clothing = "clothing"
    case electronics = "electronics"
    case beauty = "beauty"
    case sports = "sports"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "غذا"
        case .subscriptions: return "اشتراک‌ها"
        case .transport: return "حمل و نقل"
        case .entertainment: return "سرگرمی"
        case .health: return "سلامت"
        case .shopping: return "خرید"
        case .utilities: return "قبوض"
        case .education: return "آموزش"
        case .travel: return "سفر"
        case .restaurant: return "رستوران"
        case .grocery: return "مواد غذایی"
        case .clothing: return "پوشاک"
        case .electronics: return "الکترونیک"
        case .beauty: return "زیبایی"
        case .sports: return "ورزش"
        case .other: return "سایر"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .subscriptions: return "arrow.clockwise.circle"
        case .transport: return "car.fill"
        case .entertainment: return "tv.fill"
        case .health: return "heart.fill"
        case .shopping: return "bag.fill"
        case .utilities: return "bolt.fill"
        case .education: return "book.fill"
        case .travel: return "airplane"
        case .restaurant: return "cup.and.saucer.fill"
        case .grocery: return "cart.fill"
        case .clothing: return "tshirt.fill"
        case .electronics: return "iphone"
        case .beauty: return "sparkles"
        case .sports: return "figure.run"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return .orange
        case .subscriptions: return .purple
        case .transport: return .blue
        case .entertainment: return .pink
        case .health: return .red
        case .shopping: return .green
        case .utilities: return .yellow
        case .education: return .indigo
        case .travel: return .cyan
        case .restaurant: return Color(red: 0.9, green: 0.4, blue: 0.1)
        case .grocery: return .mint
        case .clothing: return Color(red: 0.6, green: 0.3, blue: 0.8)
        case .electronics: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .beauty: return Color(red: 0.95, green: 0.5, blue: 0.7)
        case .sports: return Color(red: 0.1, green: 0.7, blue: 0.4)
        case .other: return .gray
        }
    }

    // Keyword matching for offline AI categorization
    var keywords: [String] {
        switch self {
        case .food: return ["غذا", "ناهار", "شام", "صبحانه", "فست فود", "پیتزا", "ساندویچ"]
        case .subscriptions: return ["اشتراک", "ماهانه", "نتفلیکس", "یوتیوب", "اپل", "google", "اسپاتیفای", "فیلیمو", "نماوا"]
        case .transport: return ["تاکسی", "اسنپ", "دیجی کالا", "مترو", "بنزین", "اتوبوس", "uber"]
        case .entertainment: return ["سینما", "تئاتر", "کنسرت", "بازی", "موزه", "پارک"]
        case .health: return ["دکتر", "دارو", "بیمارستان", "داروخانه", "دندان", "پزشک", "ویزیت"]
        case .shopping: return ["خرید", "فروشگاه", "مال", "بازار"]
        case .utilities: return ["برق", "آب", "گاز", "اینترنت", "تلفن", "قبض"]
        case .education: return ["کتاب", "دوره", "آموزش", "دانشگاه", "مدرسه", "کلاس"]
        case .travel: return ["هتل", "بلیط", "سفر", "تور", "هواپیما", "ترن"]
        case .restaurant: return ["رستوران", "کافه", "چای", "قهوه", "کافی شاپ"]
        case .grocery: return ["سوپر مارکت", "میوه", "سبزی", "نان", "لبنیات", "هایپر"]
        case .clothing: return ["لباس", "کفش", "پوشاک", "ست", "مانتو", "کت"]
        case .electronics: return ["موبایل", "لپ تاپ", "تبلت", "هدفون", "شارژر", "کابل"]
        case .beauty: return ["آرایش", "عطر", "کرم", "شامپو", "آرایشگاه", "صالون"]
        case .sports: return ["ورزش", "باشگاه", "تجهیزات", "لوازم ورزشی"]
        case .other: return []
        }
    }
}

// MARK: - Expense Model

@Model
final class Expense {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var categoryRaw: String
    var date: Date
    var notes: String
    @Attribute(.externalStorage) var receiptImageData: Data?
    var merchant: String
    var isRecurring: Bool
    var recurringIntervalDays: Int
    var aiSummary: String
    var tags: [String]
    var paymentMethod: String

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        title: String,
        amount: Double,
        currency: String = "IRR",
        category: ExpenseCategory = .other,
        date: Date = Date(),
        notes: String = "",
        merchant: String = "",
        isRecurring: Bool = false,
        recurringIntervalDays: Int = 30,
        paymentMethod: String = "نقدی"
    ) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.currency = currency
        self.categoryRaw = category.rawValue
        self.date = date
        self.notes = notes
        self.merchant = merchant
        self.isRecurring = isRecurring
        self.recurringIntervalDays = recurringIntervalDays
        self.aiSummary = ""
        self.tags = []
        self.paymentMethod = paymentMethod
    }
}

// MARK: - Scanned Receipt Data

struct ScannedReceipt {
    var merchant: String = ""
    var amount: Double = 0
    var date: Date = Date()
    var items: [String] = []
    var rawText: String = ""
    var suggestedCategory: ExpenseCategory = .other
}
