import Foundation
import SwiftData

enum BillFrequency: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case fortnightly = "Fortnightly"
    case fourWeekly = "Every 4 weeks"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
    case once = "One-off"
    var id: String { rawValue }

    func next(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date)
        case .fortnightly: return calendar.date(byAdding: .day, value: 14, to: date)
        case .fourWeekly: return calendar.date(byAdding: .day, value: 28, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date)
        case .once: return nil
        }
    }

    /// Rough number of payments in a month, for the monthly total.
    var perMonth: Double {
        switch self {
        case .weekly: return 52.0 / 12.0
        case .fortnightly: return 26.0 / 12.0
        case .fourWeekly: return 13.0 / 12.0
        case .monthly: return 1
        case .quarterly: return 1.0 / 3.0
        case .yearly: return 1.0 / 12.0
        case .once: return 0
        }
    }
}

enum BillCategory: String, CaseIterable, Identifiable {
    case energy = "Energy"
    case water = "Water"
    case councilTax = "Council Tax"
    case broadband = "Broadband"
    case phone = "Phone"
    case insurance = "Insurance"
    case mortgageRent = "Mortgage / Rent"
    case subscription = "Subscription"
    case tvLicence = "TV Licence"
    case other = "Other"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .energy: return "bolt.fill"
        case .water: return "drop.fill"
        case .councilTax: return "building.columns.fill"
        case .broadband: return "wifi"
        case .phone: return "iphone"
        case .insurance: return "umbrella.fill"
        case .mortgageRent: return "house.fill"
        case .subscription: return "play.rectangle.fill"
        case .tvLicence: return "tv.fill"
        case .other: return "creditcard.fill"
        }
    }
}

/// A regular household bill, entered by hand. The app never connects to a bank or pays anything.
@Model
final class Bill {
    // Sync for shared households. Every field has a default, so the lightweight migration stays safe.
    var syncId: String = ""
    var visibilityRaw: String = "house"   // "house" (Everyone) or "me" (Just me)
    var createdBy: String = ""
    var updatedBy: String = ""
    var syncHash: String = ""
    var syncScope: String = ""
    var splitModeRaw: String = "equal"   // "equal" or "custom"
    var customSharesJSON: String = ""   // {"uid": percent} for custom splits

    var name: String = ""
    var categoryRaw: String = BillCategory.other.rawValue
    var amount: Double = 0
    /// True when the amount changes each time and is a rough figure.
    var isEstimate: Bool = false
    var frequencyRaw: String = BillFrequency.monthly.rawValue
    var nextDueDate: Date = Date()
    /// Typed by the user, e.g. "Direct debit" or "Pay online".
    var paymentMethod: String = ""
    var contractEndDate: Date?
    var notes: String = ""
    var remindersEnabled: Bool = true
    /// Set once a one-off bill is paid.
    var isSettled: Bool = false
    var reminderID: String?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var provider: Person?
    @Relationship(deleteRule: .cascade, inverse: \BillPayment.bill)
    var payments: [BillPayment] = []
    @Relationship(deleteRule: .nullify, inverse: \Document.bill)
    var documents: [Document] = []

    init(name: String, category: BillCategory = .other, amount: Double = 0, frequency: BillFrequency = .monthly, nextDueDate: Date = Date()) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.frequencyRaw = frequency.rawValue
        self.nextDueDate = Calendar.current.startOfDay(for: nextDueDate)
        self.createdAt = Date()
    }

    var category: BillCategory {
        get { BillCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var frequency: BillFrequency {
        get { BillFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var sortedPayments: [BillPayment] { payments.sorted { $0.paidDate > $1.paidDate } }

    /// Bills are the only things in the app that can be overdue.
    var isOverdue: Bool {
        !isSettled && Calendar.current.startOfDay(for: nextDueDate) < Calendar.current.startOfDay(for: Date())
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: nextDueDate)).day ?? 0
    }

    var monthlyEquivalent: Double { isSettled ? 0 : amount * frequency.perMonth }

    /// Contract ends within 60 days (or has ended): time to compare prices.
    var contractEndingSoon: Bool {
        guard let contractEndDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: contractEndDate).day ?? 0
        return days <= 60
    }

    /// Records a payment for the current due date and moves the due date on.
    @discardableResult
    func markPaid(amount paidAmount: Double? = nil, on date: Date = Date(), note: String = "", in context: ModelContext) -> BillPayment {
        let payment = BillPayment(amount: paidAmount ?? amount, paidDate: date, dueDate: nextDueDate, note: note)
        context.insert(payment)
        payment.bill = self
        payment.recordSplit(for: self)
        if let next = frequency.next(after: nextDueDate) {
            nextDueDate = next
        } else {
            isSettled = true
        }
        return payment
    }

    /// Undoes a payment: removes it and, if it was the latest, puts the due date back.
    func undo(_ payment: BillPayment, in context: ModelContext) {
        if let latest = sortedPayments.first, latest === payment {
            nextDueDate = payment.dueDate
            isSettled = false
        }
        context.delete(payment)
    }
}

@Model
final class BillPayment {
    // Sync for shared households. Every field has a default, so the lightweight migration stays safe.
    var syncId: String = ""
    var visibilityRaw: String = "house"   // "house" (Everyone) or "me" (Just me)
    var createdBy: String = ""
    var updatedBy: String = ""
    var syncHash: String = ""
    var syncScope: String = ""
    var paidByUid: String = ""   // member who paid the provider
    var sharesJSON: String = ""   // {"uid": amount} fixed when the payment was made
    var repaidJSON: String = ""   // {"uid": "ISO date"} shares paid back to paidByUid

    var amount: Double = 0
    var paidDate: Date = Date()
    var dueDate: Date = Date()
    var note: String = ""
    @Relationship(deleteRule: .nullify)
    var bill: Bill?

    init(amount: Double, paidDate: Date, dueDate: Date, note: String = "") {
        self.amount = amount
        self.paidDate = paidDate
        self.dueDate = dueDate
        self.note = note
    }
}
