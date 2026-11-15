import Foundation
import SwiftData

@Model
final class Floor {
    var name: String
    var floorNumber: Int
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify)
    var home: Home?
    
    init(name: String, floorNumber: Int) {
        self.name = name
        self.floorNumber = floorNumber
        self.createdAt = Date()
    }
    
    var displayName: String {
        if !name.isEmpty { return name }
        switch floorNumber {
        case 0: return "Ground"
        case 1: return "1st Floor"
        case 2: return "2nd Floor"
        case 3: return "3rd Floor"
        case let n where n > 0: return "\(n)th Floor"
        case -1: return "Basement"
        default: return "Floor \(floorNumber)"
        }
    }
}
