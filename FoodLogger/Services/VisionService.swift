import Foundation
import Vision
import UIKit

// VisionService intentionally has NO actor isolation.
// Vision's perform() is synchronous and blocking — it must run off the main thread.
// Being nonisolated means callers can await it from any actor without deadlock.
final class VisionService: Sendable {

    enum VisionError: Error, LocalizedError {
        case invalidImage

        var errorDescription: String? {
            "Could not process the selected image."
        }
    }

    /// Classifies a UIImage using Vision's on-device model.
    /// Runs on a background thread; safe to call from MainActor.
    nonisolated func classifyImage(_ image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        // Run synchronous Vision work on a background thread via unstructured task
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: orientation,
                    options: [:]
                )
                do {
                    try handler.perform([request])
                    let labels = (request.results ?? [])
                        .filter { $0.confidence > 0.3 }
                        .prefix(3)
                        .map { $0.identifier }
                    continuation.resume(returning: labels.isEmpty ? ["Unknown food item"] : Array(labels))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - UIImage orientation → CGImagePropertyOrientation

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
