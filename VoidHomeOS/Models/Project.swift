import Foundation
import SwiftData

@Model
final class Project {
    var title: String
    var projectDescription: String
    var startDate: Date?
    var endDate: Date?
    var budget: Double
    var actualCost: Double
    var status: ProjectStatus
    var notes: String
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify)
    var home: Home?
    
    @Relationship(deleteRule: .cascade)
    var contractors: [Person] = []
    
    init(title: String, description: String = "", startDate: Date? = nil, endDate: Date? = nil, budget: Double = 0.0, actualCost: Double = 0.0, status: ProjectStatus = .planned, notes: String = "") {
        self.title = title
        self.projectDescription = description
        self.startDate = startDate
        self.endDate = endDate
        self.budget = budget
        self.actualCost = actualCost
        self.status = status
        self.notes = notes
        self.createdAt = Date()
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case planned = "Planned"
    case inProgress = "In Progress"
    case completed = "Completed"
    case onHold = "On Hold"
}
