import CoreGraphics
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
    /// Room centre on the floor plan, in metres from the plan's origin. Nil for rooms saved before
    /// metre positions existed: those are converted once from xPosition/yPosition when the plan opens.
    var planX: Double?
    var planY: Double?
    
    @Relationship(deleteRule: .nullify)
    var home: Home?
    
    // Deleting a room keeps its assets and documents; they simply become unassigned.
    @Relationship(deleteRule: .nullify, inverse: \Asset.room)
    var assets: [Asset] = []

    @Relationship(deleteRule: .nullify, inverse: \Document.room)
    var documents: [Document] = []

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

// MARK: - Floor plan geometry

/// Geometry for the floor plan, in metres. Room rotation is applied in 90° steps around the room's
/// centre, so every piece stays an axis-aligned rectangle and overlap and snapping are exact.
enum FloorplanGeometry {
    /// Points per metre at 1x zoom. Room sizes and positions both use it, so the plan is the same on every screen.
    static let pointsPerMetre: CGFloat = 35

    /// Rotation snapped to 0, 90, 180 or 270.
    static func quarterTurns(_ degrees: Double) -> Int {
        let normalised = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return Int((normalised / 90).rounded()) % 4
    }

    /// Rotates a local offset (metres, y down) by the room's rotation, matching SwiftUI's clockwise rotationEffect.
    static func rotate(_ p: CGPoint, quarterTurns: Int) -> CGPoint {
        switch quarterTurns {
        case 1: return CGPoint(x: -p.y, y: p.x)
        case 2: return CGPoint(x: -p.x, y: -p.y)
        case 3: return CGPoint(x: p.y, y: -p.x)
        default: return p
        }
    }

    /// The room's pieces in its own unrotated frame, centred on (0,0): the main rectangle first, then each extra piece.
    static func localRects(width: Double, height: Double, parts: [RoomPart]) -> [CGRect] {
        var rects = [CGRect(x: -width / 2, y: -height / 2, width: width, height: height)]
        for part in parts {
            rects.append(CGRect(x: part.xOffset - part.width / 2, y: part.yOffset - part.height / 2,
                                width: part.width, height: part.height))
        }
        return rects
    }

    /// Converts a local rect to plan coordinates for a room centred at `center` with the given rotation.
    static func worldRect(_ local: CGRect, center: CGPoint, quarterTurns: Int) -> CGRect {
        let a = rotate(CGPoint(x: local.minX, y: local.minY), quarterTurns: quarterTurns)
        let b = rotate(CGPoint(x: local.maxX, y: local.maxY), quarterTurns: quarterTurns)
        return CGRect(x: min(a.x, b.x) + center.x, y: min(a.y, b.y) + center.y,
                      width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    static func center(of room: Room) -> CGPoint {
        CGPoint(x: room.planX ?? 0, y: room.planY ?? 0)
    }

    /// All pieces of a room in plan coordinates, optionally at a different centre (used while dragging).
    static func worldRects(for room: Room, center: CGPoint? = nil) -> [CGRect] {
        let c = center ?? self.center(of: room)
        let turns = quarterTurns(room.rotation)
        return localRects(width: room.width, height: room.height, parts: room.parts)
            .map { worldRect($0, center: c, quarterTurns: turns) }
    }

    /// The smallest rect containing every piece.
    static func bounds(of rects: [CGRect]) -> CGRect {
        rects.dropFirst().reduce(rects.first ?? .zero) { $0.union($1) }
    }

    /// True when any piece of one set overlaps any piece of the other by more than `tolerance` metres on both axes.
    static func overlaps(_ a: [CGRect], _ b: [CGRect], tolerance: CGFloat = 0.02) -> Bool {
        for r in a {
            for o in b {
                let ix = min(r.maxX, o.maxX) - max(r.minX, o.minX)
                let iy = min(r.maxY, o.maxY) - max(r.minY, o.minY)
                if ix > tolerance && iy > tolerance { return true }
            }
        }
        return false
    }

    /// A centre near `preferred` where a room of these pieces (local rects, already rotated) overlaps none of `obstacles`.
    /// Searches outward in rings on a 0.5 m grid, keeping a small gap between rooms.
    static func freeCenter(near preferred: CGPoint, localRects: [CGRect], quarterTurns: Int, obstacles: [[CGRect]], gap: CGFloat = 0.5) -> CGPoint {
        let padded = obstacles.map { $0.map { $0.insetBy(dx: -gap, dy: -gap) } }
        func fits(_ c: CGPoint) -> Bool {
            let rects = localRects.map { worldRect($0, center: c, quarterTurns: quarterTurns) }
            return !padded.contains { overlaps(rects, $0, tolerance: 0) }
        }
        if fits(preferred) { return preferred }
        let step: CGFloat = 0.5
        for ring in 1...80 {
            let r = CGFloat(ring)
            var candidates: [CGPoint] = []
            for i in -ring...ring {
                let d = CGFloat(i)
                candidates.append(CGPoint(x: preferred.x + d * step, y: preferred.y - r * step))
                candidates.append(CGPoint(x: preferred.x + d * step, y: preferred.y + r * step))
                candidates.append(CGPoint(x: preferred.x - r * step, y: preferred.y + d * step))
                candidates.append(CGPoint(x: preferred.x + r * step, y: preferred.y + d * step))
            }
            let sorted = candidates.sorted {
                hypot($0.x - preferred.x, $0.y - preferred.y) < hypot($1.x - preferred.x, $1.y - preferred.y)
            }
            if let hit = sorted.first(where: fits) { return hit }
        }
        return preferred
    }

    /// Converts a legacy room's normalised position (share of the canvas it was last shown on) into metres,
    /// with the plan origin at the canvas centre, so it appears exactly where it was on this screen.
    static func migrateLegacyPosition(of room: Room, canvasSize: CGSize) {
        guard room.planX == nil || room.planY == nil, canvasSize.width > 0, canvasSize.height > 0 else { return }
        room.planX = Double((room.xPosition - 0.5) * canvasSize.width / pointsPerMetre)
        room.planY = Double((room.yPosition - 0.5) * canvasSize.height / pointsPerMetre)
    }
}

extension FloorplanGeometry {
    /// The piece a door sits on, in the room's own unrotated frame (metres, centred on the room).
    /// A door whose piece was removed falls back to the main rectangle.
    static func hostRect(for door: Door, in room: Room) -> CGRect {
        if let part = door.part, room.parts.contains(where: { $0 === part }) {
            return CGRect(x: part.xOffset - part.width / 2, y: part.yOffset - part.height / 2,
                          width: part.width, height: part.height)
        }
        return CGRect(x: -room.width / 2, y: -room.height / 2, width: room.width, height: room.height)
    }
}
