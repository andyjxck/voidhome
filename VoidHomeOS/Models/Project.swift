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
    
    /// Deleting a project must never delete the people on it.
    @Relationship(deleteRule: .nullify)
    var contractors: [Person] = []
    @Relationship(deleteRule: .nullify, inverse: \Room.projects)
    var rooms: [Room] = []
    @Relationship(deleteRule: .nullify, inverse: \Asset.projects)
    var assets: [Asset] = []
    @Relationship(deleteRule: .nullify, inverse: \Document.project)
    var documents: [Document] = []
    @Relationship(deleteRule: .cascade, inverse: \HomeTask.project)
    var tasks: [HomeTask] = []
    @Relationship(deleteRule: .cascade, inverse: \ProjectPhoto.project)
    var photos: [ProjectPhoto] = []

    /// Share of the project's jobs that are done (0...1), or nil when it has none.
    var taskProgress: Double? {
        let jobs = tasks.filter { $0.repeatRule == .none }
        guard !jobs.isEmpty else { return nil }
        return Double(jobs.filter(\.isDone).count) / Double(jobs.count)
    }
    
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

extension Person {
    /// Projects this person is on (projects hold the link).
    func projects(in all: [Project]) -> [Project] {
        all.filter { project in project.contractors.contains { $0.persistentModelID == self.persistentModelID } }
    }
}
