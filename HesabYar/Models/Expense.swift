import SwiftData
import SwiftUI
import Foundation

// MARK: - Category

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food, subscriptions, transport, entertainment, health, shopping
    case utilities, education, travel, restaurant, grocery, clothing
    case electronics, beauty, sports, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food:          return AppSettings.shared.t("Food", "غذا")
        case .subscriptions: return AppSettings.shared.t("Subscriptions", "اشتراک‌ها")
        case .transport:     return AppSettings.shared.t("Transport", "حمل و نقل")
        case .entertainment: return AppSettings.shared.t("Entertainment", "سرگرمی")
        case .health:        return AppSettings.shared.t("Health", "سلامت")
        case .shopping:      return AppSettings.shared.t("Shopping", "خرید")
        case .utilities:     return AppSettings.shared.t("Utilities", "قبوض")
        case .education:     return AppSettings.shared.t("Education", "آموزش")
        case .travel:        return AppSettings.shared.t("Travel", "سفر")
        case .restaurant:    return AppSettings.shared.t("Restaurant", "رستوران")
        case .grocery:       return AppSettings.shared.t("Grocery", "مواد غذایی")
        case .clothing:      return AppSettings.shared.t("Clothing", "پوشاک")
        case .electronics:   return AppSettings.shared.t("Electronics", "الکترونیک")
        case .beauty:        return AppSettings.shared.t("Beauty", "زیبایی")
        case .sports:        return AppSettings.shared.t("Sports", "ورزش")
        case .other:         return AppSettings.shared.t("Other", "سایر")
        }
    }

    var icon: String {
        switch self {
        case .food:          return "fork.knife"
        case .subscriptions: return "arrow.clockwise.circle"
        case .transport:     return "car.fill"
        case .entertainment: return "tv.fill"
        case .health:        return "heart.fill"
        case .shopping:      return "bag.fill"
        case .utilities:     return "bolt.fill"
        case .education:     return "book.fill"
        case .travel:        return "airplane"
        case .restaurant:    return "cup.and.saucer.fill"
        case .grocery:       return "cart.fill"
        case .clothing:      return "tshirt.fill"
        case .electronics:   return "iphone"
        case .beauty:        return "sparkles"
        case .sports:        return "figure.run"
        case .other:         return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food:          return .orange
        case .subscriptions: return .purple
        case .transport:     return .blue
        case .entertainment: return .pink
        case .health:        return .red
        case .shopping:      return .green
        case .utilities:     return .yellow
        case .education:     return .indigo
        case .travel:        return .cyan
        case .restaurant:    return Color(red: 0.9, green: 0.4, blue: 0.1)
        case .grocery:       return .mint
        case .clothing:      return Color(red: 0.6, green: 0.3, blue: 0.8)
        case .electronics:   return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .beauty:        return Color(red: 0.95, green: 0.5, blue: 0.7)
        case .sports:        return Color(red: 0.1, green: 0.7, blue: 0.4)
        case .other:         return .gray
        }
    }

    var keywords: [String] {
        switch self {
        case .food:          return ["food", "lunch", "dinner", "breakfast", "pizza", "sandwich", "غذا", "ناهار", "شام"]
        case .subscriptions: return ["subscription", "monthly", "netflix", "youtube", "spotify", "اشتراک", "ماهانه"]
        case .transport:     return ["taxi", "uber", "metro", "gas", "fuel", "petrol", "تاکسی", "بنزین", "مترو"]
        case .entertainment: return ["cinema", "movie", "concert", "game", "theater", "سینما", "بازی"]
        case .health:        return ["doctor", "pharmacy", "medicine", "hospital", "dental", "دکتر", "دارو", "داروخانه"]
        case .shopping:      return ["shopping", "store", "mall", "market", "خرید", "فروشگاه"]
        case .utilities:     return ["electricity", "water", "gas", "internet", "phone", "bill", "برق", "آب", "قبض"]
        case .education:     return ["book", "course", "university", "school", "class", "کتاب", "دوره", "آموزش"]
        case .travel:        return ["hotel", "flight", "trip", "tour", "airline", "هتل", "بلیط", "سفر"]
        case .restaurant:    return ["restaurant", "cafe", "coffee", "رستوران", "کافه", "قهوه"]
        case .grocery:       return ["supermarket", "grocery", "fruit", "vegetable", "dairy", "سوپر", "میوه"]
        case .clothing:      return ["clothing", "shoes", "fashion", "apparel", "لباس", "کفش", "پوشاک"]
        case .electronics:   return ["phone", "laptop", "tablet", "headphones", "charger", "موبایل", "لپ تاپ"]
        case .beauty:        return ["makeup", "perfume", "cream", "shampoo", "salon", "آرایش", "عطر"]
        case .sports:        return ["gym", "sports", "fitness", "equipment", "ورزش", "باشگاه"]
        case .other:         return []
        }
    }
}

// MARK: - Financial Insight

struct FinancialInsight: Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var icon: String
    var type: InsightType
    var amount: Double? = nil
    var category: ExpenseCategory? = nil

    enum InsightType { case info, warning, tip, achievement }
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
        currency: String = "USD",
        category: ExpenseCategory = .other,
        date: Date = Date(),
        notes: String = "",
        merchant: String = "",
        isRecurring: Bool = false,
        recurringIntervalDays: Int = 30,
        paymentMethod: String = "Cash"
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
