import Foundation
import SwiftData
import UIKit

@Model
final class Document {
    var title: String
    var type: DocumentType
    var fileURL: String
    var ocrText: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var asset: Asset?

    init(title: String, type: DocumentType, fileURL: String, ocrText: String = "") {
        self.title = title
        self.type = type
        self.fileURL = fileURL
        self.ocrText = ocrText
        self.createdAt = Date()
    }

    /// Returns a file URL if fileURL points to a real file in the sandbox.
    /// Handles sandbox container UUID changes between launches.
    var localFileURL: URL? {
        guard !fileURL.isEmpty else { return nil }
        let fm = FileManager.default
        let directURL = URL(fileURLWithPath: fileURL)
        if fm.fileExists(atPath: directURL.path) {
            return directURL
        }
        
        // When the app container UUID changes on relaunch, resolve relative to current documents dir
        if let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileName = directURL.lastPathComponent
            let inUploaded = docsDir.appendingPathComponent("UploadedDocuments").appendingPathComponent(fileName)
            if fm.fileExists(atPath: inUploaded.path) {
                return inUploaded
            }
            let inDocs = docsDir.appendingPathComponent(fileName)
            if fm.fileExists(atPath: inDocs.path) {
                return inDocs
            }
        }
        return nil
    }

    /// Returns the file extension if a file is attached
    var fileExtension: String? {
        guard !fileURL.isEmpty else { return nil }
        let url = URL(fileURLWithPath: fileURL)
        let ext = url.pathExtension
        return ext.isEmpty ? nil : ext
    }
}

enum DocumentType: String, Codable, CaseIterable {
    case manual = "Manual"
    case receipt = "Receipt"
    case invoice = "Invoice"
    case certificate = "Certificate"
    case guarantee = "Guarantee"
    case other = "Other"
}
