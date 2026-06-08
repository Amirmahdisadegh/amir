import SwiftData
import Foundation

@Model
final class Debt {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var isOwedToMe: Bool   // true = someone owes me | false = I owe someone
    var personName: String
    var dueDate: Date?
    var date: Date
    var notes: String
    var isPaid: Bool
    var paidDate: Date?
    var reminderEnabled: Bool

    init(
        title: String,
        amount: Double,
        currency: String = "IRR",
        isOwedToMe: Bool,
        personName: String,
        dueDate: Date? = nil,
        date: Date = Date(),
        notes: String = "",
        reminderEnabled: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.currency = currency
        self.isOwedToMe = isOwedToMe
        self.personName = personName
        self.dueDate = dueDate
        self.date = date
        self.notes = notes
        self.isPaid = false
        self.paidDate = nil
        self.reminderEnabled = reminderEnabled
    }

    var isOverdue: Bool {
        guard !isPaid, let due = dueDate else { return false }
        return due < Date()
    }

    var remainingDays: Int? {
        guard !isPaid, let due = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: due).day
    }
}
