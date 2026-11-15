import Foundation
import SwiftData

/// A door placed on an edge of a room.
/// position is 0.0 to 1.0 along the edge (0 = left/top, 1 = right/bottom)
/// hingeSide determines which end the hinge is on (left/right for top/bottom edges, top/bottom for left/right edges)
/// opensInward determines whether the door swings into the room (true) or out of it (false)
@Model
final class Door {
    var edge: DoorEdge
    var position: Double
    var opensLeft: Bool = true
    var opensInward: Bool = true
    var isDoubleDoor: Bool = false
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var room: Room?

    init(edge: DoorEdge = .bottom, position: Double = 0.5, opensLeft: Bool = true, opensInward: Bool = true, isDoubleDoor: Bool = false) {
        self.edge = edge
        self.position = position
        self.opensLeft = opensLeft
        self.opensInward = opensInward
        self.isDoubleDoor = isDoubleDoor
        self.createdAt = Date()
    }
}

enum DoorEdge: String, Codable, CaseIterable {
    case top = "Top"
    case bottom = "Bottom"
    case left = "Left"
    case right = "Right"
}
