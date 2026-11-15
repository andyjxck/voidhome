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
