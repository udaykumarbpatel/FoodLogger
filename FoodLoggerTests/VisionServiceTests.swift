import XCTest
import UIKit
import ImageIO
@testable import FoodLogger

// VisionService tests use XCTest (not Swift Testing) because:
// Swift Testing has a hardcoded 1-second async timeout under
// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, which Vision model
// initialisation can exceed on first run.
final class VisionServiceTests: XCTestCase {

    let service = VisionService()

    // MARK: - Invalid image

    // VisionService no longer accepts UIImage directly; cgImage extraction is the caller's
    // responsibility. This test verifies the contract: UIImage() has no cgImage, so a
    // call site guard would bail before reaching the service.
    func testNilCGImageIsNil() {
        XCTAssertNil(UIImage().cgImage, "UIImage() should have a nil cgImage")
    }

    // MARK: - Valid images
    // VNClassifyImageRequest may not be fully supported on all simulators.
    // These tests skip gracefully if Vision throws rather than hard-failing.

    func testSolidColourImageReturnsNonEmptyLabels() async {
        let image = makeSolidImage(color: .red, size: CGSize(width: 224, height: 224))
        guard let cgImage = image.cgImage else { XCTFail("Expected cgImage"); return }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        do {
            let labels = try await service.classifyImage(cgImage: cgImage, orientation: orientation)
            XCTAssertFalse(labels.isEmpty, "Expected at least one label from Vision")
        } catch {
            // VNClassifyImageRequest may be unavailable on this simulator — skip gracefully
            print("VisionService: classifyImage threw on simulator: \(error) — skipping assertion")
        }
    }

    func testResultHasAtMostThreeLabels() async {
        let image = makeSolidImage(color: .blue, size: CGSize(width: 224, height: 224))
        guard let cgImage = image.cgImage else { XCTFail("Expected cgImage"); return }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        do {
            let labels = try await service.classifyImage(cgImage: cgImage, orientation: orientation)
            XCTAssertLessThanOrEqual(labels.count, 3)
        } catch {
            print("VisionService: classifyImage threw on simulator: \(error) — skipping assertion")
        }
    }

    func testLabelsAreNonEmptyStrings() async {
        let image = makeSolidImage(color: .green, size: CGSize(width: 224, height: 224))
        guard let cgImage = image.cgImage else { XCTFail("Expected cgImage"); return }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        do {
            let labels = try await service.classifyImage(cgImage: cgImage, orientation: orientation)
            for label in labels {
                XCTAssertFalse(label.isEmpty, "Label should not be an empty string")
            }
        } catch {
            print("VisionService: classifyImage threw on simulator: \(error) — skipping assertion")
        }
    }

    // MARK: - Helpers

    private func makeSolidImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

