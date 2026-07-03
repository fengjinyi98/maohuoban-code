import XCTest
@testable import maohuoban

// PetAlbumStoreMutationTests 相册本地状态变更测试
// 核心职责：
// - 固化后端命令返回后的相册展示状态规则
// - 防止菜单动作脱离单一 Store 数据源
final class PetAlbumStoreMutationTests: XCTestCase {
    @MainActor
    func testDeleteAssetRemovesPhotoAndUpdatesAlbumCount() async {
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
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: PetAlbumStoreTestRepository(),
            albums: [album],
            assetsByAlbumID: [album.id: [firstAsset, secondAsset]]
        )

        await store.deleteAsset(id: firstAsset.id, in: album.id)

        XCTAssertEqual(store.assets(for: album.id), [secondAsset])
        XCTAssertEqual(store.album(id: album.id)?.photoCount, 1)
    }

    @MainActor
    func testDeleteAlbumRemovesSummaryAndAssets() async {
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "糯米",
            updatedText: "今天更新",
            photoCount: 1,
            coverImageAssetName: "HomeGalleryAlbum1"
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: PetAlbumStoreTestRepository(),
            albums: [album],
            assetsByAlbumID: [album.id: []]
        )

        await store.deleteAlbum(id: album.id)

        XCTAssertNil(store.album(id: album.id))
        XCTAssertEqual(store.assets(for: album.id), [])
    }

    @MainActor
    func testTogglePinnedUpdatesAlbumPinnedState() async {
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "糯米",
            updatedText: "今天更新",
            photoCount: 1,
            coverImageAssetName: "HomeGalleryAlbum1"
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: PetAlbumStoreTestRepository(),
            albums: [album],
            assetsByAlbumID: [:]
        )

        await store.togglePinned(albumID: album.id)

        XCTAssertEqual(store.album(id: album.id)?.isPinned, true)
    }

    @MainActor
    func testLoadAlbumsReplacesLocalStateWithRepositoryData() async {
        let repository = PetAlbumStoreTestRepository()
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository
        )

        await store.loadAlbums(force: true)

        XCTAssertEqual(store.albums.map(\.id), ["album"])
        XCTAssertEqual(store.album(id: "album")?.petName, "糯米")
        XCTAssertNil(store.errorMessage)
    }
}

private extension PetAlbumStoreMutationTests {
    // PetAlbumStoreTestRepository 相册 Store 测试仓库
    // 核心职责：
    // - 返回固定相册和照片数据
    // - 记录 Store 发起的后端命令语义
    final class PetAlbumStoreTestRepository: PetAlbumRepository {
        func listAlbums(
            petID: String,
            currentUserID: String,
            limit: Int,
            cursor: String?
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumListData> {
            MHBAPIResponse(
                success: true,
                code: "pet_album.list_loaded",
                message: "相册列表已加载",
                data: PetAlbumDTO.AlbumListData(
                    items: [Self.albumData(isPinned: false, photoCount: 1)],
                    nextCursor: nil
                )
            )
        }

        func createAlbum(
            petID: String,
            draft: PetAlbumCreateDraft,
            currentUserID: String
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
            MHBAPIResponse(
                success: true,
                code: "pet_album.created",
                message: "相册已创建",
                data: Self.albumData(title: draft.normalizedName, isPinned: false, photoCount: 0)
            )
        }

        func loadAlbum(
            albumID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumDetailData> {
            MHBAPIResponse(
                success: true,
                code: "pet_album.loaded",
                message: "相册已加载",
                data: PetAlbumDTO.AlbumDetailData(album: Self.albumData(isPinned: false, photoCount: 1))
            )
        }

        func updateAlbum(
            albumID: String,
            draft: PetAlbumCreateDraft,
            currentUserID: String
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
            MHBAPIResponse(
                success: true,
                code: "pet_album.updated",
                message: "相册已更新",
                data: Self.albumData(title: draft.normalizedName, isPinned: false, photoCount: 1)
            )
        }

        func updateAlbumPinned(
            albumID: String,
            isPinned: Bool,
            currentUserID: String
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
            MHBAPIResponse(
                success: true,
                code: "pet_album.updated",
                message: "相册已更新",
                data: Self.albumData(isPinned: isPinned, photoCount: 1)
            )
        }

        func archiveAlbum(
            albumID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
            MHBAPIResponse(
                success: true,
                code: "pet_album.archived",
                message: "相册已归档",
                data: Self.albumData(isPinned: false, photoCount: 1)
            )
        }

        func listAssets(
            albumID: String,
            currentUserID: String,
            limit: Int,
            cursor: String?
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AssetListData> {
            MHBAPIResponse(
                success: true,
                code: "pet_album.assets_loaded",
                message: "照片已加载",
                data: PetAlbumDTO.AssetListData(items: [], nextCursor: nil)
            )
        }

        func removeAsset(
            albumAssetID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumDetailData> {
            MHBAPIResponse(
                success: true,
                code: "pet_album.asset_removed",
                message: "照片已移除",
                data: PetAlbumDTO.AlbumDetailData(album: Self.albumData(isPinned: false, photoCount: 1))
            )
        }

        private static func albumData(
            title: String = "成长记录",
            isPinned: Bool,
            photoCount: Int
        ) -> PetAlbumDTO.AlbumData {
            PetAlbumDTO.AlbumData(
                id: "album",
                petID: "pet-1",
                ownerUserID: "user-1",
                title: title,
                description: nil,
                isPrivate: false,
                isPinned: isPinned,
                coverAssetID: nil,
                coverURL: "/media/cover.jpg",
                photoCount: photoCount,
                archivedAt: nil,
                createdAt: "2026-07-01T12:00:00Z",
                updatedAt: "2026-07-03T12:00:00Z"
            )
        }
    }
}
