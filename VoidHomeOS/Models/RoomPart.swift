import Foundation
import SwiftData

/// A rectangular segment that extends a room's shape beyond its base rectangle.
/// Coordinates are relative to the room's center, in meters.
/// Used for irregular room shapes (L-shaped, T-shaped, etc.)
@Model
final class RoomPart {
    // Sync for shared households. Every field has a default, so the lightweight migration stays safe.
    var syncId: String = ""
    var visibilityRaw: String = "house"   // "house" (Everyone) or "me" (Just me)
    var createdBy: String = ""
    var updatedBy: String = ""
    var syncHash: String = ""
    var syncScope: String = ""

    var name: String
    var width: Double      // in meters
    var height: Double     // in meters
    var xOffset: Double    // offset from room center, in meters
    var yOffset: Double    // offset from room center, in meters
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var room: Room?

    /// Doors placed on this piece's edges; removed with the piece.
    @Relationship(deleteRule: .cascade, inverse: \Door.part)
    var doors: [Door] = []

    init(name: String = "Part", width: Double = 1.0, height: Double = 1.0, xOffset: Double = 0, yOffset: Double = 0) {
        self.name = name
        self.width = width
        self.height = height
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.createdAt = Date()
    }
}
