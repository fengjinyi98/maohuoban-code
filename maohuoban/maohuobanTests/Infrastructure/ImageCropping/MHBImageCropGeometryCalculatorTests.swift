import XCTest
@testable import maohuoban

// MHBImageCropGeometryCalculatorTests 图片裁剪几何测试
// 核心职责：
// - 固化裁剪页初始展示尺寸不主动放大图片
// - 保证裁剪坐标按实际展示尺寸换算到原图像素坐标系
@MainActor
final class MHBImageCropGeometryCalculatorTests: XCTestCase {
    func testInitialDisplaySizeKeepsSmallImageAtOriginalPointSize() {
        let displaySize = MHBImageCropDisplayGeometryCalculator.initialDisplaySize(
            imagePointSize: CGSize(width: 120, height: 80),
            viewportSize: CGSize(width: 400, height: 800)
        )

        XCTAssertEqual(displaySize.width, 120, accuracy: 0.0001)
        XCTAssertEqual(displaySize.height, 80, accuracy: 0.0001)
    }

    func testInitialDisplaySizeScalesLargeImageDownToFitViewport() {
        let displaySize = MHBImageCropDisplayGeometryCalculator.initialDisplaySize(
            imagePointSize: CGSize(width: 1200, height: 800),
            viewportSize: CGSize(width: 400, height: 800)
        )

        XCTAssertEqual(displaySize.width, 400, accuracy: 0.0001)
        XCTAssertEqual(displaySize.height, 266.6667, accuracy: 0.0001)
    }

    func testRectInitialDisplaySizeCoversCropFrame() {
        let displaySize = MHBImageCropDisplayGeometryCalculator.initialDisplaySize(
            imagePointSize: CGSize(width: 120, height: 80),
            viewportSize: CGSize(width: 400, height: 800),
            minimumCoverSize: CGSize(width: 400, height: 266.6667)
        )

        XCTAssertEqual(displaySize.width, 400, accuracy: 0.0001)
        XCTAssertEqual(displaySize.height, 266.6667, accuracy: 0.0001)
    }

    func testRectCropRectUsesActualInitialDisplaySize() {
        let cropRect = MHBRectImageCropGeometryCalculator.cropRect(
            imagePixelSize: CGSize(width: 100, height: 100),
            imageDisplaySize: CGSize(width: 100, height: 100),
            viewportSize: CGSize(width: 400, height: 800),
            imageScale: 1,
            imageOffset: .zero,
            cropFrameSize: CGSize(width: 100, height: 100)
        )

        XCTAssertEqual(cropRect.origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(cropRect.origin.y, 0, accuracy: 0.0001)
        XCTAssertEqual(cropRect.width, 100, accuracy: 0.0001)
        XCTAssertEqual(cropRect.height, 100, accuracy: 0.0001)
    }

    func testCircularCropRectUsesActualInitialDisplaySize() {
        let cropRect = MHBCircularImageCropGeometryCalculator.cropRect(
            imagePixelSize: CGSize(width: 100, height: 100),
            imageDisplaySize: CGSize(width: 100, height: 100),
            viewportSize: CGSize(width: 400, height: 800),
            imageScale: 1,
            imageOffset: .zero,
            cropRadius: 50
        )

        XCTAssertEqual(cropRect.origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(cropRect.origin.y, 0, accuracy: 0.0001)
        XCTAssertEqual(cropRect.width, 100, accuracy: 0.0001)
        XCTAssertEqual(cropRect.height, 100, accuracy: 0.0001)
    }

    func testCircularCropRectForFullWidthPortraitImageStaysWithinPixelBoundsAfterIntegral() {
        let imagePixelSize = CGSize(width: 1440, height: 1982)
        let boundedRect = MHBCircularImageCropGeometryCalculator.boundedIntegralCropRect(
            MHBCircularImageCropGeometryCalculator.cropRect(
                imagePixelSize: imagePixelSize,
                imageDisplaySize: CGSize(width: 392.99999999999994, height: 540.9208333333332),
                viewportSize: CGSize(width: 393, height: 852),
                imageScale: 1,
                imageOffset: .zero,
                cropRadius: 196.5
            ),
            imagePixelSize: imagePixelSize
        )

        XCTAssertTrue(
            CGRect(origin: .zero, size: imagePixelSize).contains(boundedRect),
            "boundedRect=\(boundedRect) should stay inside image bounds"
        )
        XCTAssertEqual(boundedRect.origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(boundedRect.origin.y, 270, accuracy: 0.0001)
        XCTAssertEqual(boundedRect.width, 1440, accuracy: 0.0001)
        XCTAssertEqual(boundedRect.height, 1440, accuracy: 0.0001)
    }
}
