import Foundation
import SwiftData

@Model
final class Home {
    // Sync for shared households. Every field has a default, so the lightweight migration stays safe.
    var syncId: String = ""
    var visibilityRaw: String = "house"   // "house" (Everyone) or "me" (Just me)
    var createdBy: String = ""
    var updatedBy: String = ""
    var syncHash: String = ""
    var syncScope: String = ""

    var name: String
    var address: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Room.home)
    var rooms: [Room] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Asset.home)
    var assets: [Asset] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Project.home)
    var projects: [Project] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Floor.home)
    var floors: [Floor] = []
    
    init(name: String, address: String) {
        self.name = name
        self.address = address
        self.createdAt = Date()
    }
}
