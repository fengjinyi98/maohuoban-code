import XCTest
@testable import maohuoban

// MHBMediaUploadEncoderTests 媒体上传编码器测试
// 核心职责：
// - 固化头像用途的 JPEG 输出和像素上限
// - 保留透明素材用途的 PNG 编码能力
@MainActor
final class MHBMediaUploadEncoderTests: XCTestCase {
    func testAvatarAlphaImageEncodesAsJPEGWithinAvatarPixelLimit() throws {
        let image = Self.makeImage(
            size: CGSize(width: 3_000, height: 1_500),
            opaque: false
        )

        let encoded = try XCTUnwrap(
            MHBMediaUploadEncoder.encode(
                image: image,
                purpose: .avatar,
                fileName: "profile-avatar"
            )
        )

        XCTAssertEqual(encoded.mimeType, "image/jpeg")
        XCTAssertEqual(encoded.fileName, "profile-avatar.jpg")
        XCTAssertEqual(encoded.pixelWidth, 2_048)
        XCTAssertEqual(encoded.pixelHeight, 1_024)
        XCTAssertLessThanOrEqual(encoded.data.count, 8 * 1024 * 1024)
    }

    func testTransparentCommodityImagePreservesPNGEncoding() throws {
        let image = Self.makeImage(
            size: CGSize(width: 320, height: 180),
            opaque: false
        )

        let encoded = try XCTUnwrap(
            MHBMediaUploadEncoder.encode(
                image: image,
                purpose: .commodityImage,
                fileName: "transparent-commodity"
            )
        )

        XCTAssertEqual(encoded.mimeType, "image/png")
        XCTAssertEqual(encoded.fileName, "transparent-commodity.png")
    }

    private static func makeImage(size: CGSize, opaque: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            if opaque {
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            UIColor.systemTeal.withAlphaComponent(0.72).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
    }
}
