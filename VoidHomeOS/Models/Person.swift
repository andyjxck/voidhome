import Foundation
import SwiftData

@Model
final class Person {
    var name: String
    var company: String
    var role: String
    var phoneNumber: String
    var email: String
    var notes: String
    var createdAt: Date
    /// Household member, tradesperson or provider. Existing people were all contractors.
    var kindRaw: String = PersonKind.tradesperson.rawValue

    @Relationship(deleteRule: .nullify, inverse: \HomeTask.assignee)
    var assignedTasks: [HomeTask] = []
    @Relationship(deleteRule: .nullify, inverse: \Maintenance.person)
    var maintenanceWork: [Maintenance] = []
    @Relationship(deleteRule: .nullify, inverse: \Bill.provider)
    var bills: [Bill] = []
    @Relationship(deleteRule: .nullify, inverse: \MaintenancePlan.person)
    var maintenancePlans: [MaintenancePlan] = []

    var kind: PersonKind {
        get { PersonKind(rawValue: kindRaw) ?? .tradesperson }
        set { kindRaw = newValue.rawValue }
    }
    
    init(name: String, company: String = "", role: String = "", phoneNumber: String = "", email: String = "", notes: String = "") {
        self.name = name
        self.company = company
        self.role = role
        self.phoneNumber = phoneNumber
        self.email = email
        self.notes = notes
        self.createdAt = Date()
    }
}

enum PersonKind: String, CaseIterable, Identifiable {
    case household = "Household"
    case tradesperson = "Tradesperson"
    case provider = "Provider"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .household: return "house.fill"
        case .tradesperson: return "hammer.fill"
        case .provider: return "building.2.fill"
        }
    }
}
