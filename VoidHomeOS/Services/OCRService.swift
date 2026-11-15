import Vision
import UIKit

class OCRService {
    static func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                continuation.resume(returning: "")
            }
        }
    }
    
    static func extractReceiptInfo(from text: String) -> ReceiptInfo {
        var info = ReceiptInfo()
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if info.retailer.isEmpty {
                if trimmedLine.count > 3 && !trimmedLine.contains("$") && !trimmedLine.contains("Total") {
                    info.retailer = trimmedLine
                }
            }
            
            if let dateRange = trimmedLine.range(of: "\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}", options: .regularExpression) {
                let dateString = String(trimmedLine[dateRange])
                info.date = parseDate(from: dateString)
            }
            
            if let priceRange = trimmedLine.range(of: "\\$?\\d+\\.\\d{2}", options: .regularExpression) {
                let priceString = String(trimmedLine[priceRange]).replacingOccurrences(of: "$", with: "")
                if let price = Double(priceString) {
                    if trimmedLine.localizedCaseInsensitiveContains("total") {
                        info.total = price
                    } else if price > info.total {
                        info.total = price
                    }
                }
            }
        }
        
        return info
    }
    
    private static func parseDate(from dateString: String) -> Date? {
        let formatters = [
            DateFormatter().then { $0.dateFormat = "MM/dd/yyyy" },
            DateFormatter().then { $0.dateFormat = "MM-dd-yyyy" },
            DateFormatter().then { $0.dateFormat = "M/d/yy" },
            DateFormatter().then { $0.dateFormat = "M-d-yy" }
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
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
