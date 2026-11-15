import Foundation
import SwiftData

@Model
final class Room {
    var name: String
    var floor: String = ""
    var floorNumber: Int = 0 // Provide default value for migration
    var width: Double = 3.0 // Default width in meters
    var height: Double = 4.0 // Default height in meters
    var dimensions: String = ""
    var rotation: Double = 0.0 // Rotation in degrees
    var createdAt: Date
    var xPosition: Double = 0.5 // Default center normalized coordinates
    var yPosition: Double = 0.5 // Default center normalized coordinates
    
    @Relationship(deleteRule: .nullify)
    var home: Home?
    
    @Relationship(deleteRule: .cascade, inverse: \Asset.room)
    var assets: [Asset] = []

    @Relationship(deleteRule: .cascade, inverse: \RoomPart.room)
    var parts: [RoomPart] = []

    @Relationship(deleteRule: .cascade, inverse: \Door.room)
    var doors: [Door] = []
    
    // Computed property for display since many views might still expect a string
    var floorDisplay: String {
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
    
    // Helper for dimensions display
    var dimensionsDisplay: String {
        return String(format: "%.1fm x %.1fm", width, height)
    }
    
    init(name: String, floorNumber: Int = 0, width: Double = 3.0, height: Double = 4.0, rotation: Double = 0.0, xPosition: Double = 0.5, yPosition: Double = 0.5) {
        self.name = name
        self.floorNumber = floorNumber
        self.width = width
        self.height = height
        self.rotation = rotation
        self.createdAt = Date()
        self.xPosition = xPosition
        self.yPosition = yPosition
        
        // Populate legacy fields for migration safety
        self.dimensions = "\(width)m x \(height)m"
        switch floorNumber {
        case 0: self.floor = "Ground"
        case 1: self.floor = "1st Floor"
        case -1: self.floor = "Basement"
        default: self.floor = "Floor \(floorNumber)"
        }
    }
}
