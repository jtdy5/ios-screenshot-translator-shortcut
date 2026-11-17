import UIKit
import Vision
import Translation

@MainActor
class TranslationState: ObservableObject {
    static let shared = TranslationState()
    @Published var incomingImage: UIImage?
    @Published var previewFileURL: URL?
}

struct RecognizedBlock {
    let text: String
    let boundingBox: CGRect // Normalized Vision coordinates (origin bottom-left)
}

class OverlayProcessor {
    /// Step 1: Extract text and bounding boxes using Vision
    static func extractText(from image: UIImage) async throws -> [RecognizedBlock] {
        guard let cgImage = image.cgImage else { return [] }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let blocks = observations.compactMap { obs -> RecognizedBlock? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return RecognizedBlock(text: candidate.string, boundingBox: obs.boundingBox)
                }
                continuation.resume(returning: blocks)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Step 2: Render translated text boxes onto the screenshot and save for Quick Look
    static func renderOverlay(on image: UIImage, blocks: [RecognizedBlock], translations: [String]) -> URL? {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let renderedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
            
            for (index, block) in blocks.enumerated() where index < translations.count {
                let translatedText = translations[index]
                
                // Convert Vision normalized coordinates (bottom-left) to UIKit (top-left)
                let rect = CGRect(
                    x: block.boundingBox.origin.x * size.width,
                    y: (1 - block.boundingBox.origin.y - block.boundingBox.height) * size.height,
                    width: block.boundingBox.width * size.width,
                    height: block.boundingBox.height * size.height
                )
                
                // Draw translucent dark pill background over original text
                let pillPath = UIBezierPath(roundedRect: rect.insetBy(dx: -4, dy: -2), cornerRadius: 6)
                UIColor.black.withAlphaComponent(0.78).setFill()
                pillPath.fill()
                
                // Auto-fit font size to box height
                let fontSize = max(12, rect.height * 0.72)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: UIColor.white
                ]
                
                let textRect = rect.insetBy(dx: 2, dy: 1)
                translatedText.draw(in: textRect, withAttributes: attributes)
            }
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TranslatedOverlay.png")
        if let pngData = renderedImage.pngData() {
            try? pngData.write(to: tempURL)
            return tempURL
        }
        return nil
    }
}