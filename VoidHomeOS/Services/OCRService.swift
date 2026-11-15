import Vision
import UIKit
import PDFKit

/// On-device text recognition for scanned pages, photos and PDFs, plus a simple receipt reader.
enum OCRService {

    /// Recognises text in one image. Runs Vision off the main thread.
    static func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = true
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgOrientation, options: [:])
                do {
                    try handler.perform([request])
                    let text = (request.results ?? [])
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    continuation.resume(returning: text)
                } catch {
                    print("OCR Error: \(error)")
                    continuation.resume(returning: "")
                }
            }
        }
    }

    /// Recognises text across several pages, in order, separated by blank lines.
    static func recognizeText(from images: [UIImage]) async -> String {
        var pages: [String] = []
        for image in images {
            let text = await recognizeText(from: image)
            if !text.isEmpty { pages.append(text) }
        }
        return pages.joined(separator: "\n\n")
    }

    /// Reads the text of a stored file: a PDF's own text layer (falling back to OCR of its pages
    /// when it is a scan), or OCR for an image file. Other file types return "".
    static func extractText(fromFileAt url: URL) async -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else { return "" }
            let embedded = (pdf.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !embedded.isEmpty { return embedded }
            // A scanned PDF has no text layer: render up to 10 pages and OCR them.
            var images: [UIImage] = []
            for index in 0..<min(pdf.pageCount, 10) {
                guard let page = pdf.page(at: index) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                images.append(page.thumbnail(of: size, for: .mediaBox))
            }
            return await recognizeText(from: images)
        }
        if ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp"].contains(ext),
           let image = UIImage(contentsOfFile: url.path) {
            return await recognizeText(from: image)
        }
        if ["txt", "text", "md", "csv"].contains(ext) {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        return ""
    }

    // MARK: - Receipts

    static func extractReceiptInfo(from text: String) -> ReceiptInfo {
        var info = ReceiptInfo()
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let amountPattern = "[£$€]?\\s?\\d{1,3}(?:[,.]\\d{3})*[.,]\\d{2}(?!\\d)"
        let totalKeywords = ["total", "amount due", "balance due", "to pay", "grand total", "amount paid", "card"]
        var keywordTotal: Double?
        var largest: Double = 0

        for line in lines {
            let lower = line.lowercased()

            if info.retailer.isEmpty, line.count > 2,
               line.range(of: "\\d", options: .regularExpression) == nil || line.count > 12,
               line.range(of: amountPattern, options: .regularExpression) == nil,
               !totalKeywords.contains(where: { lower.contains($0) }) {
                info.retailer = line
            }

            if info.date == nil,
               let range = line.range(of: "\\d{1,2}[/.-]\\d{1,2}[/.-]\\d{2,4}", options: .regularExpression) {
                info.date = parseDate(from: String(line[range]))
            }

            if let range = line.range(of: amountPattern, options: .regularExpression),
               let amount = parseAmount(String(line[range])) {
                largest = max(largest, amount)
                let isTotalLine = totalKeywords.contains { lower.contains($0) }
                    && !lower.contains("subtotal") && !lower.contains("sub total")
                if isTotalLine { keywordTotal = amount }
            }
        }

        info.total = keywordTotal ?? largest
        return info
    }

    private static func parseAmount(_ raw: String) -> Double? {
        var digits = raw.filter { "0123456789.,".contains($0) }
        guard digits.count >= 4 else { return nil }
        // The last separator is the decimal mark; any others are thousands separators.
        let decimalMark = digits[digits.index(digits.endIndex, offsetBy: -3)]
        let thousands: Character = decimalMark == "," ? "." : ","
        digits.removeAll { $0 == thousands }
        return Double(digits.replacingOccurrences(of: ",", with: "."))
    }

    private static func parseDate(from dateString: String) -> Date? {
        let normalised = dateString.replacingOccurrences(of: ".", with: "/").replacingOccurrences(of: "-", with: "/")
        // Day-first everywhere except regions that write the month first.
        let monthFirst = Locale.current.region?.identifier == "US"
        let year = (normalised.split(separator: "/").last?.count ?? 4) == 2 ? "yy" : "yyyy"
        let patterns = (monthFirst ? ["M/d/", "d/M/"] : ["d/M/", "M/d/"]).map { $0 + year }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.isLenient = false
        for pattern in patterns {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: normalised) { return date }
        }
        return nil
    }
}

struct ReceiptInfo {
    var retailer: String = ""
    var date: Date? = nil
    var total: Double = 0.0
}

extension DateFormatter {
    func then(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self)
        return self
    }
}

extension UIImage {
    /// The image's orientation in the form Vision expects.
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
