import SwiftUI
import VisionKit

@available(iOS 16.0, *)
struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var scannedImages: [UIImage]
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                images.append(image)
            }
            parent.scannedImages = images
            parent.isPresented = false
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.isPresented = false
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.isPresented = false
        }
    }
}

// MARK: - Scanner availability and file storage

enum DocumentScanner {
    /// True on devices with a camera that VisionKit's document scanner supports (false in the Simulator).
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    /// Builds a multi-page PDF from scanned page images, each page sized to its image.
    static func makePDF(from images: [UIImage]) -> Data? {
        guard let first = images.first else { return nil }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: first.size))
        return renderer.pdfData { context in
            for image in images {
                let bounds = CGRect(origin: .zero, size: image.size)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                image.draw(in: bounds)
            }
        }
    }
}

/// Where imported and scanned files live: Documents/UploadedDocuments inside the app's sandbox.
enum DocumentStorage {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("UploadedDocuments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A destination in the storage folder that does not overwrite an existing file.
    static func uniqueURL(baseName: String, ext: String) -> URL {
        let safeBase = baseName.isEmpty ? "Document" : baseName.replacingOccurrences(of: "/", with: "-")
        var url = directory.appendingPathComponent(ext.isEmpty ? safeBase : "\(safeBase).\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: url.path) {
            let name = "\(safeBase)_\(counter)"
            url = directory.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
            counter += 1
        }
        return url
    }

    /// Copies a picked file (which may be security-scoped) into storage. Returns the stored path, or nil.
    static func importFile(from source: URL) -> String? {
        let dest = uniqueURL(baseName: source.deletingPathExtension().lastPathComponent, ext: source.pathExtension)
        let didAccess = source.startAccessingSecurityScopedResource()
        defer { if didAccess { source.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: source, to: dest)
            return dest.path
        } catch {
            if let data = try? Data(contentsOf: source), (try? data.write(to: dest)) != nil {
                return dest.path
            }
            print("Could not import file: \(error)")
            return nil
        }
    }

    /// Writes data (e.g. a scanned PDF) into storage. Returns the stored path, or nil.
    static func write(_ data: Data, baseName: String, ext: String) -> String? {
        let dest = uniqueURL(baseName: baseName, ext: ext)
        do {
            try data.write(to: dest)
            return dest.path
        } catch {
            print("Could not save scanned document: \(error)")
            return nil
        }
    }
}
