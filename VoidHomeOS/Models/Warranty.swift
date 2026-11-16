import Foundation
import SwiftData

@Model
final class Warranty {
    var provider: String
    var startDate: Date
    var expiryDate: Date
    var notes: String
    var createdAt: Date
    /// Stable id for the local reminder; assigned when a reminder is first scheduled.
    var reminderID: String?
    /// Whether an expiry reminder should be scheduled.
    var remindersEnabled: Bool = true
    
    @Relationship(deleteRule: .nullify)
    var asset: Asset?
    /// Who to contact to claim: name, phone, email or web address.
    var claimContact: String = ""
    @Relationship(deleteRule: .nullify, inverse: \Document.warranty)
    var documents: [Document] = []

    enum Status: String { case active = "Active", endingSoon = "Ending soon", expired = "Expired" }

    var status: Status {
        if isExpired { return .expired }
        if let d = daysUntilExpiry, d <= 60 { return .endingSoon }
        return .active
    }

    /// Share of the cover period still left (0...1).
    var remainingFraction: Double {
        let total = expiryDate.timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return min(1, max(0, expiryDate.timeIntervalSinceNow / total))
    }
    
    init(provider: String, startDate: Date, expiryDate: Date, notes: String = "") {
        self.provider = provider
        self.startDate = startDate
        self.expiryDate = expiryDate
        self.notes = notes
        self.createdAt = Date()
    }
    
    var isExpired: Bool {
        return Date() > expiryDate
    }
    
    var daysUntilExpiry: Int? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiryDate)
        return components.day
    }
}
