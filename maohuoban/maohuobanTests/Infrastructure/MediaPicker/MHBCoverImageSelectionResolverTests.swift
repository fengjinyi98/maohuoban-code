import XCTest
import UIKit
@testable import maohuoban

// MHBCoverImageSelectionResolverTests 封面选择结果解析测试
// 核心职责：
// - 固化普通图片选择作为封面预览
// - 固化 Live Photo 选择使用预览图作为封面预览
@MainActor
final class MHBCoverImageSelectionResolverTests: XCTestCase {
    func testResolveImageResultReturnsFirstImage() {
        let image = UIImage()
        let result = MHBMediaPickerResult(images: [image])

        let resolvedImage = MHBCoverImageSelectionResolver.resolveImage(from: result)

        XCTAssertTrue(resolvedImage === image)
    }

    func testResolveLivePhotoResultReturnsPreviewImage() {
        let image = UIImage()
        let livePhoto = MHBPickedLivePhoto(
            stillURL: URL(fileURLWithPath: "/tmp/cover.heic"),
            pairedVideoURL: URL(fileURLWithPath: "/tmp/cover.mov"),
            previewImage: image
        )
        let result = MHBMediaPickerResult(livePhotos: [livePhoto])

        let resolvedImage = MHBCoverImageSelectionResolver.resolveImage(from: result)

        XCTAssertTrue(resolvedImage === image)
    }
}
