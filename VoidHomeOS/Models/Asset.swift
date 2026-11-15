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
    
    @Relationship(deleteRule: .nullify)
    var home: Home?
    
    @Relationship(deleteRule: .nullify)
    var room: Room?
    
    @Relationship(deleteRule: .cascade, inverse: \Document.asset)
    var documents: [Document] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Warranty.asset)
    var warranties: [Warranty] = []
    
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
}
