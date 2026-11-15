import Foundation
import SwiftData

@Model
final class Home {
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
