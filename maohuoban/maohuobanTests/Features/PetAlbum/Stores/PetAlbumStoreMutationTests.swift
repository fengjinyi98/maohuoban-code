import XCTest
@testable import maohuoban

// PetAlbumStoreMutationTests 相册本地状态变更测试
// 核心职责：
// - 固化快速 UI 阶段相册删除和照片删除的本地状态规则
// - 防止菜单动作只更新界面而没有同步展示数据
final class PetAlbumStoreMutationTests: XCTestCase {
    @MainActor
    func testDeleteAssetRemovesPhotoAndUpdatesAlbumCount() {
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "糯米",
            updatedText: "今天更新",
            photoCount: 2,
            coverImageAssetName: "HomeGalleryAlbum1"
        )
        let firstAsset = PetAlbumAsset(
            id: "asset-1",
            albumID: album.id,
            imageAssetName: "HomeGalleryAlbum1",
            pixelSize: PetAlbumImageSize(width: 100, height: 100),
            source: .userUpload,
            caption: nil
        )
        let secondAsset = PetAlbumAsset(
            id: "asset-2",
            albumID: album.id,
            imageAssetName: "HomeGalleryAlbum2",
            pixelSize: PetAlbumImageSize(width: 100, height: 100),
            source: .userUpload,
            caption: nil
        )
        let store = PetAlbumStore(
            albums: [album],
            assetsByAlbumID: [album.id: [firstAsset, secondAsset]]
        )

        store.deleteAsset(id: firstAsset.id, in: album.id)

        XCTAssertEqual(store.assets(for: album.id), [secondAsset])
        XCTAssertEqual(store.album(id: album.id)?.photoCount, 1)
    }

    @MainActor
    func testDeleteAlbumRemovesSummaryAndAssets() {
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "糯米",
            updatedText: "今天更新",
            photoCount: 1,
            coverImageAssetName: "HomeGalleryAlbum1"
        )
        let store = PetAlbumStore(
            albums: [album],
            assetsByAlbumID: [album.id: []]
        )

        store.deleteAlbum(id: album.id)

        XCTAssertNil(store.album(id: album.id))
        XCTAssertEqual(store.assets(for: album.id), [])
    }

    @MainActor
    func testTogglePinnedUpdatesAlbumPinnedState() {
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "糯米",
            updatedText: "今天更新",
            photoCount: 1,
            coverImageAssetName: "HomeGalleryAlbum1"
        )
        let store = PetAlbumStore(
            albums: [album],
            assetsByAlbumID: [:]
        )

        store.togglePinned(albumID: album.id)

        XCTAssertEqual(store.album(id: album.id)?.isPinned, true)
    }
}
