import Foundation
import SwiftData

@Model
final class Maintenance {
    var task: String
    var date: Date
    var cost: Double
    var notes: String
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify)
    var asset: Asset?
    
    init(task: String, date: Date, cost: Double = 0.0, notes: String = "") {
        self.task = task
        self.date = date
        self.cost = cost
        self.notes = notes
        self.createdAt = Date()
    }
}
