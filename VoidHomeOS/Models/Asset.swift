import Foundation
import SwiftData

@Model
final class Asset {
    var name: String
    var category: String
    var manufacturer: String
    var model: String
    var serialNumber: String
    var purchaseDate: Date?
    var purchasePrice: Double
    var location: String
    var notes: String
    var createdAt: Date
    /// File name of the asset's photo in the app's Photos folder.
    var photoFileName: String?
    
    @Relationship(deleteRule: .nullify)
    var home: Home?
    
    @Relationship(deleteRule: .nullify)
    var room: Room?
    
    // Documents are independent records in the Documents section, so deleting an asset unlinks them rather than deleting them.
    @Relationship(deleteRule: .nullify, inverse: \Document.asset)
    var documents: [Document] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Warranty.asset)
    var warranties: [Warranty] = []
    
    @Relationship(deleteRule: .nullify, inverse: \MaintenancePlan.asset)
    var maintenancePlans: [MaintenancePlan] = []
    @Relationship(deleteRule: .nullify)
    var projects: [Project] = []

    @Relationship(deleteRule: .cascade, inverse: \Maintenance.asset)
    var maintenanceRecords: [Maintenance] = []
    
    init(name: String, category: String, manufacturer: String = "", model: String = "", serialNumber: String = "", purchaseDate: Date? = nil, purchasePrice: Double = 0.0, location: String = "", notes: String = "") {
        self.name = name
        self.category = category
        self.manufacturer = manufacturer
        self.model = model
        self.serialNumber = serialNumber
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.location = location
        self.notes = notes
        self.createdAt = Date()
    }

    /// Where the asset is: its linked room if it has one, otherwise the legacy free-text location.
    var locationDisplay: String {
        if let room { return room.name }
        return location
    }
}
