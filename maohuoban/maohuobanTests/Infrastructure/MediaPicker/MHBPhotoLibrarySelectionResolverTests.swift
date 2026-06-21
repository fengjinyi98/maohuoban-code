import XCTest
import UIKit
@testable import maohuoban

// MHBPhotoLibrarySelectionResolverTests PhotoKit 选择结果解析测试
// 核心职责：
// - 固化普通照片选择进入图片结果
// - 固化 Live Photo 选择优先进入 Live Photo 结果
@MainActor
final class MHBPhotoLibrarySelectionResolverTests: XCTestCase {
    func testResolveImageSelectionReturnsImageResult() {
        let image = UIImage()
        let selection = MHBResolvedPhotoLibrarySelection(
            image: image,
            livePhoto: nil
        )

        let result = MHBPhotoLibrarySelectionResolver.resolve(selection)
        let images = result.images
        let videos = result.videos
        let livePhotos = result.livePhotos

        XCTAssertEqual(images.count, 1)
        XCTAssertTrue(images.first === image)
        XCTAssertTrue(videos.isEmpty)
        XCTAssertTrue(livePhotos.isEmpty)
    }

    func testResolveLivePhotoSelectionPrefersLivePhotoResult() {
        let image = UIImage()
        let livePhoto = MHBPickedLivePhoto(
            stillURL: URL(fileURLWithPath: "/tmp/live-photo.heic"),
            pairedVideoURL: URL(fileURLWithPath: "/tmp/live-photo.mov"),
            previewImage: image
        )
        let selection = MHBResolvedPhotoLibrarySelection(
            image: image,
            livePhoto: livePhoto
        )

        let result = MHBPhotoLibrarySelectionResolver.resolve(selection)
        let images = result.images
        let videos = result.videos
        let livePhotos = result.livePhotos
        let resolvedStillURL = livePhotos.first?.stillURL
        let resolvedPairedVideoURL = livePhotos.first?.pairedVideoURL
        let expectedStillURL = livePhoto.stillURL
        let expectedPairedVideoURL = livePhoto.pairedVideoURL

        XCTAssertTrue(images.isEmpty)
        XCTAssertTrue(videos.isEmpty)
        XCTAssertEqual(livePhotos.count, 1)
        XCTAssertEqual(resolvedStillURL, expectedStillURL)
        XCTAssertEqual(resolvedPairedVideoURL, expectedPairedVideoURL)
    }
}
