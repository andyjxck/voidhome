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
