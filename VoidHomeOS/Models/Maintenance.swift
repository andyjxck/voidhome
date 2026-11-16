import Foundation
import SwiftData

@Model
final class Maintenance {
    // Sync for shared households. Every field has a default, so the lightweight migration stays safe.
    var syncId: String = ""
    var visibilityRaw: String = "house"   // "house" (Everyone) or "me" (Just me)
    var createdBy: String = ""
    var updatedBy: String = ""
    var syncHash: String = ""
    var syncScope: String = ""

    var task: String
    var date: Date
    var cost: Double
    var notes: String
    var createdAt: Date
    /// Stable id for the local reminder; assigned when a reminder is first scheduled.
    var reminderID: String?
    /// Whether a reminder should be scheduled before this task's date.
    var remindersEnabled: Bool = true
    
    @Relationship(deleteRule: .nullify)
    var asset: Asset?
    @Relationship(deleteRule: .nullify)
    var room: Room?
    @Relationship(deleteRule: .nullify)
    var person: Person?
    @Relationship(deleteRule: .nullify)
    var plan: MaintenancePlan?
    @Relationship(deleteRule: .nullify, inverse: \Document.maintenance)
    var documents: [Document] = []

    var targetName: String? { asset?.name ?? room?.name }
    
    init(task: String, date: Date, cost: Double = 0.0, notes: String = "") {
        self.task = task
        self.date = date
        self.cost = cost
        self.notes = notes
        self.createdAt = Date()
    }
}
