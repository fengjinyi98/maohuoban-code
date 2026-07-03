import XCTest
import MaohuobanDesignSystem
@testable import maohuoban

// PetAlbumImageSourceResolverTests 相册图片源解析测试
// 核心职责：
// - 固化相册后端相对 URL 的远端图片语义
// - 防止照片墙把后端媒资地址误当成本地 asset 名称
@MainActor
final class PetAlbumImageSourceResolverTests: XCTestCase {
    private let baseURL = URL(string: "http://127.0.0.1:18080")!

    func testRelativeBackendPathResolvesToRemotePreviewSource() {
        let source = PetAlbumImageSourceResolver.previewSourceKind(
            from: "/api/v1/media/assets/asset-1/content",
            baseURL: baseURL
        )

        XCTAssertEqual(source, .remote("http://127.0.0.1:18080/api/v1/media/assets/asset-1/content"))
    }

    func testHTTPURLResolvesToRemotePreviewSource() {
        let source = PetAlbumImageSourceResolver.previewSourceKind(
            from: "https://img.maohuoban.test/photo.jpg",
            baseURL: baseURL
        )

        XCTAssertEqual(source, .remote("https://img.maohuoban.test/photo.jpg"))
    }

    func testLocalAssetNameResolvesToLocalPreviewSource() {
        let source = PetAlbumImageSourceResolver.previewSourceKind(
            from: "HomeGalleryAlbum1",
            baseURL: baseURL
        )

        XCTAssertEqual(source, .localAsset("HomeGalleryAlbum1"))
    }

    func testRelativeBackendPathResolvesToDisplayURL() {
        let url = PetAlbumImageSourceResolver.remoteURL(
            from: "/api/v1/media/assets/asset-1/content",
            baseURL: baseURL
        )

        XCTAssertEqual(url?.absoluteString, "http://127.0.0.1:18080/api/v1/media/assets/asset-1/content")
    }
}
