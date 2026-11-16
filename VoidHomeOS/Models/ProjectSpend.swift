import Foundation
import SwiftData

/// One amount spent on a project. In a shared house, an "Everyone" spend is split between
/// members like a bill (the payer is owed the others' shares); a "Just me" spend stays personal.
@Model
final class ProjectSpend {
    // Sync for shared households. Every field has a default, so the lightweight migration stays safe.
    var syncId: String = ""
    var visibilityRaw: String = "house"
    var createdBy: String = ""
    var updatedBy: String = ""
    var syncHash: String = ""
    var syncScope: String = ""

    var amount: Double = 0
    var note: String = ""
    var date: Date = Date()
    var paidByUid: String = ""
    var sharesJSON: String = ""   // {"uid": amount}; empty means nobody owes anything
    var repaidJSON: String = ""   // {"uid": "ISO date"}
    var createdAt: Date = Date()
    var project: Project?

    init(amount: Double, note: String = "", date: Date = Date()) {
        self.amount = amount
        self.note = note
        self.date = date
        self.createdAt = Date()
    }
}

extension Project {
    /// What this viewer sees as spent: the house figure plus their own "Just me" spending.
    var totalSpent: Double {
        actualCost + spends.filter { $0.visibilityRaw == "me" }.reduce(0) { $0 + $1.amount }
    }
}
