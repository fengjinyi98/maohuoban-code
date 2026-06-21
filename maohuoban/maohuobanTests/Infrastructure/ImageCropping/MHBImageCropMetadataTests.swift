import XCTest
@testable import maohuoban

// MHBImageCropMetadataTests 图片裁剪元数据测试
// 核心职责：
// - 固化像素裁剪框到归一化裁剪元数据的转换
// - 保证 Live Photo 上传保留稳定的展示裁剪契约
@MainActor
final class MHBImageCropMetadataTests: XCTestCase {
    func testNormalizedMetadataClampsCropRectToImageBounds() {
        let metadata = MHBImageCropMetadata.normalized(
            cropRect: CGRect(x: 100, y: 200, width: 400, height: 300),
            imagePixelSize: CGSize(width: 800, height: 800)
        )

        XCTAssertEqual(metadata.x, 0.125, accuracy: 0.0001)
        XCTAssertEqual(metadata.y, 0.25, accuracy: 0.0001)
        XCTAssertEqual(metadata.width, 0.5, accuracy: 0.0001)
        XCTAssertEqual(metadata.height, 0.375, accuracy: 0.0001)
    }
}
