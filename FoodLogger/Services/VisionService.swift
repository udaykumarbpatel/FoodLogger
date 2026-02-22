import Foundation
import Vision

// VisionService intentionally has NO actor isolation.
// Vision's perform() is synchronous and blocking — it must run off the main thread.
// Being nonisolated means callers can await it from any actor without deadlock.
//
// Accepts CGImage + CGImagePropertyOrientation rather than UIImage so that
// UIImage property access (which is MainActor-bound in Swift 6) stays with the caller.
final class VisionService: Sendable {

    enum VisionError: Error, LocalizedError {
        case invalidImage

        var errorDescription: String? {
            "Could not process the selected image."
        }
    }

    /// Classifies an image using Vision's on-device model.
    /// The caller (on MainActor) must extract cgImage and orientation from UIImage
    /// before calling this method.
    /// Runs on a background thread; safe to call from any actor.
    nonisolated func classifyImage(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> [String] {
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
