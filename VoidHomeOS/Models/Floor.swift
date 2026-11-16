import Foundation
import SwiftData

@Model
final class Floor {
    // Sync for shared households. Every field has a default, so the lightweight migration stays safe.
    var syncId: String = ""
    var visibilityRaw: String = "house"   // "house" (Everyone) or "me" (Just me)
    var createdBy: String = ""
    var updatedBy: String = ""
    var syncHash: String = ""
    var syncScope: String = ""

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
