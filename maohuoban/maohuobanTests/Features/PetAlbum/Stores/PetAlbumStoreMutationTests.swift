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
            serverAssetID: "server-asset-1",
            imageAssetName: "HomeGalleryAlbum1",
            pixelSize: PetAlbumImageSize(width: 100, height: 100),
            source: .userUpload,
            caption: nil
        )
        let secondAsset = PetAlbumAsset(
            id: "asset-2",
            albumID: album.id,
            serverAssetID: "server-asset-2",
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
        XCTAssertEqual(store.album(id: "album")?.petName, "全部宠物")
        XCTAssertNil(store.errorMessage)
    }

    @MainActor
    func testCreateAlbumUploadsCoverBeforeCreatingAlbum() async {
        let repository = PetAlbumStoreTestRepository()
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository
        )

        let didCreate = await store.createAlbum(
            draft: PetAlbumCreateDraft(name: "成长记录", isPrivate: false),
            coverUploadDraft: Self.uploadDraft(fileName: "cover.jpg")
        )

        XCTAssertTrue(didCreate)
        XCTAssertEqual(repository.recordedEvents, [
            .uploadMedia(fileName: "cover.jpg"),
            .createAlbum(coverAssetID: "asset-uploaded-1")
        ])
        XCTAssertEqual(store.albums.first?.coverImageAssetName, "/media/uploaded.jpg")
    }

    @MainActor
    func testUploadPhotosUploadsAndBindsAssetsToAlbum() async {
        let repository = PetAlbumStoreTestRepository()
        let localLinkStore = PetAlbumLocalAssetLinkMemoryStore()
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "全部宠物",
            updatedText: "今天更新",
            photoCount: 0,
            coverImageAssetName: "photo.on.rectangle.angled"
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository,
            localAssetLinkStore: localLinkStore,
            albums: [album],
            assetsByAlbumID: [album.id: []]
        )

        let didUpload = await store.uploadPhotos(
            to: album.id,
            drafts: [
                PetAlbumPhotoUploadDraft(media: Self.uploadDraft(fileName: "photo-1.jpg"), localIdentifier: "local-1"),
                PetAlbumPhotoUploadDraft(media: Self.uploadDraft(fileName: "photo-2.jpg"), localIdentifier: "local-2")
            ]
        )

        XCTAssertTrue(didUpload)
        XCTAssertEqual(repository.recordedEvents, [
            .uploadMedia(fileName: "photo-1.jpg"),
            .addAsset(assetID: "asset-uploaded-1", albumID: "album"),
            .uploadMedia(fileName: "photo-2.jpg"),
            .addAsset(assetID: "asset-uploaded-2", albumID: "album")
        ])
        XCTAssertEqual(store.assets(for: album.id).count, 2)
        XCTAssertEqual(store.assets(for: album.id).map(\.id), ["album-asset-1", "album-asset-2"])
        XCTAssertEqual(store.assets(for: album.id).compactMap(\.localIdentifier), ["local-1", "local-2"])
        XCTAssertEqual(store.disabledLocalIdentifiers(for: album.id), ["local-1", "local-2"])
        XCTAssertEqual(
            localLinkStore.links(userID: "user-1", albumID: album.id).map(\.localIdentifier),
            ["local-1", "local-2"]
        )
        XCTAssertEqual(store.album(id: album.id)?.photoCount, 2)
        XCTAssertEqual(store.uploadPlaceholders(for: album.id), [])
    }

    @MainActor
    func testLoadAssetsRestoresDisabledLocalIdentifiersFromPersistedLinks() async {
        let repository = PetAlbumStoreTestRepository()
        repository.listAssetItems = [
            PetAlbumDTO.AssetData(
                id: "album-asset-1",
                albumID: "album",
                petID: nil,
                assetID: "asset-photo-1",
                assetURL: "/media/photo-1.jpg",
                sha256Hex: "sha-photo-1",
                addedByUserID: "user-1",
                caption: nil,
                width: 1200,
                height: 900,
                sortTakenAt: "2026-07-01T12:00:00Z",
                removedAt: nil,
                createdAt: "2026-07-01T12:00:00Z",
                updatedAt: "2026-07-01T12:00:00Z"
            )
        ]
        let localLinkStore = PetAlbumLocalAssetLinkMemoryStore()
        localLinkStore.upsert(
            PetAlbumLocalAssetLink(
                userID: "user-1",
                albumID: "album",
                serverAssetID: "asset-photo-1",
                localIdentifier: "local-photo-1",
                fingerprint: "sha-photo-1",
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "全部宠物",
            updatedText: "今天更新",
            photoCount: 1,
            coverImageAssetName: "photo.on.rectangle.angled"
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository,
            localAssetLinkStore: localLinkStore,
            albums: [album]
        )

        await store.loadAssets(for: album.id, force: true)

        XCTAssertEqual(store.assets(for: album.id).compactMap(\.localIdentifier), ["local-photo-1"])
        XCTAssertEqual(store.disabledLocalIdentifiers(for: album.id), ["local-photo-1"])
    }

    @MainActor
    func testLoadAssetsRestoresLatestLocalIdentifierWhenPersistedLinksAreDuplicated() async {
        let repository = PetAlbumStoreTestRepository()
        repository.listAssetItems = [
            PetAlbumDTO.AssetData(
                id: "album-asset-1",
                albumID: "album",
                petID: nil,
                assetID: "asset-photo-1",
                assetURL: "/media/photo-1.jpg",
                sha256Hex: "sha-photo-1",
                addedByUserID: "user-1",
                caption: nil,
                width: 1200,
                height: 900,
                sortTakenAt: "2026-07-01T12:00:00Z",
                removedAt: nil,
                createdAt: "2026-07-01T12:00:00Z",
                updatedAt: "2026-07-01T12:00:00Z"
            )
        ]
        let localLinkStore = PetAlbumLocalAssetLinkMemoryStore()
        localLinkStore.appendWithoutDeduplication(
            PetAlbumLocalAssetLink(
                userID: "user-1",
                albumID: "album",
                serverAssetID: "asset-photo-1",
                localIdentifier: "local-photo-old",
                fingerprint: "sha-photo-1",
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )
        localLinkStore.appendWithoutDeduplication(
            PetAlbumLocalAssetLink(
                userID: "user-1",
                albumID: "album",
                serverAssetID: "asset-photo-1",
                localIdentifier: "local-photo-new",
                fingerprint: "sha-photo-1",
                createdAt: Date(timeIntervalSince1970: 2)
            )
        )
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "全部宠物",
            updatedText: "今天更新",
            photoCount: 1,
            coverImageAssetName: "photo.on.rectangle.angled"
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository,
            localAssetLinkStore: localLinkStore,
            albums: [album]
        )

        await store.loadAssets(for: album.id, force: true)

        XCTAssertEqual(store.assets(for: album.id).compactMap(\.localIdentifier), ["local-photo-new"])
        XCTAssertEqual(store.disabledLocalIdentifiers(for: album.id), ["local-photo-old", "local-photo-new"])
    }

    @MainActor
    func testUploadPhotosShowsProgressPlaceholderDuringUpload() async {
        let repository = PetAlbumStoreTestRepository()
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "全部宠物",
            updatedText: "今天更新",
            photoCount: 0,
            coverImageAssetName: "photo.on.rectangle.angled"
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository,
            albums: [album],
            assetsByAlbumID: [album.id: []]
        )
        repository.onUploadProgressSent = {
            let placeholders = store.uploadPlaceholders(for: album.id)
            XCTAssertEqual(placeholders.count, 1)
            XCTAssertEqual(placeholders.first?.localIdentifier, "local-1")
            XCTAssertEqual(placeholders.first?.status, .uploading)
            XCTAssertEqual(placeholders.first?.progress ?? 0, 0.41, accuracy: 0.001)
        }

        let didUpload = await store.uploadPhotos(
            to: album.id,
            drafts: [
                PetAlbumPhotoUploadDraft(
                    media: Self.uploadDraft(fileName: "photo-1.jpg"),
                    localIdentifier: "local-1",
                    previewData: Data([8, 8, 8])
                )
            ]
        )

        XCTAssertTrue(didUpload)
        XCTAssertEqual(store.uploadPlaceholders(for: album.id), [])
        XCTAssertEqual(store.assets(for: album.id).map(\.id), ["album-asset-1"])
    }

    @MainActor
    func testUploadPhotosKeepsExistingAssetsBeforeProgressPlaceholder() async {
        let repository = PetAlbumStoreTestRepository()
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "全部宠物",
            updatedText: "今天更新",
            photoCount: 1,
            coverImageAssetName: "photo.on.rectangle.angled"
        )
        let existingAsset = PetAlbumAsset(
            id: "existing-asset",
            albumID: album.id,
            serverAssetID: "server-existing-asset",
            imageAssetName: "/media/existing.jpg",
            pixelSize: PetAlbumImageSize(width: 1200, height: 900),
            source: .userUpload,
            caption: nil
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository,
            albums: [album],
            assetsByAlbumID: [album.id: [existingAsset]]
        )
        repository.onUploadProgressSent = {
            XCTAssertEqual(store.assets(for: album.id).map(\.id), ["existing-asset"])
            XCTAssertEqual(store.uploadPlaceholders(for: album.id).map(\.localIdentifier), ["local-2"])
            XCTAssertEqual(store.uploadPlaceholders(for: album.id).map(\.targetAssetIndex), [1])
        }

        let didUpload = await store.uploadPhotos(
            to: album.id,
            drafts: [
                PetAlbumPhotoUploadDraft(
                    media: Self.uploadDraft(fileName: "photo-2.jpg"),
                    localIdentifier: "local-2",
                    previewData: Data([8, 8, 8])
                )
            ]
        )

        XCTAssertTrue(didUpload)
        XCTAssertEqual(store.assets(for: album.id).map(\.id), ["existing-asset", "album-asset-1"])
        XCTAssertEqual(store.uploadPlaceholders(for: album.id), [])
    }

    @MainActor
    func testUploadPhotosAssignsStableTargetIndexesForPlaceholders() async {
        let repository = PetAlbumStoreTestRepository()
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "全部宠物",
            updatedText: "今天更新",
            photoCount: 1,
            coverImageAssetName: "photo.on.rectangle.angled"
        )
        let existingAsset = PetAlbumAsset(
            id: "existing-asset",
            albumID: album.id,
            serverAssetID: "server-existing-asset",
            imageAssetName: "/media/existing.jpg",
            pixelSize: PetAlbumImageSize(width: 1200, height: 900),
            source: .userUpload,
            caption: nil
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository,
            albums: [album],
            assetsByAlbumID: [album.id: [existingAsset]]
        )
        var firstObservedPlaceholderIndexes: [Int] = []
        repository.onUploadProgressSent = {
            if firstObservedPlaceholderIndexes.isEmpty {
                firstObservedPlaceholderIndexes = store.uploadPlaceholders(for: album.id).map(\.targetAssetIndex)
            }
        }

        _ = await store.uploadPhotos(
            to: album.id,
            drafts: [
                PetAlbumPhotoUploadDraft(
                    media: Self.uploadDraft(fileName: "photo-2.jpg"),
                    localIdentifier: "local-2",
                    previewData: Data([8, 8, 8])
                ),
                PetAlbumPhotoUploadDraft(
                    media: Self.uploadDraft(fileName: "photo-3.jpg"),
                    localIdentifier: "local-3",
                    previewData: Data([9, 9, 9])
                )
            ]
        )

        XCTAssertEqual(firstObservedPlaceholderIndexes, [1, 2])
    }

    @MainActor
    func testUploadPhotosKeepsFailedPlaceholderWhenUploadFails() async {
        let repository = PetAlbumStoreTestRepository()
        repository.uploadError = .transport("upload failed")
        let album = PetAlbumSummary(
            id: "album",
            title: "成长记录",
            petName: "全部宠物",
            updatedText: "今天更新",
            photoCount: 0,
            coverImageAssetName: "photo.on.rectangle.angled"
        )
        let store = PetAlbumStore(
            context: PetAlbumEntryContext(petID: "pet-1", petName: "糯米"),
            currentUserID: "user-1",
            repository: repository,
            albums: [album],
            assetsByAlbumID: [album.id: []]
        )

        let didUpload = await store.uploadPhotos(
            to: album.id,
            drafts: [
                PetAlbumPhotoUploadDraft(
                    media: Self.uploadDraft(fileName: "photo-1.jpg"),
                    localIdentifier: "local-1",
                    previewData: Data([8, 8, 8])
                )
            ]
        )

        XCTAssertFalse(didUpload)
        XCTAssertEqual(store.assets(for: album.id), [])
        XCTAssertEqual(store.uploadPlaceholders(for: album.id).count, 1)
        XCTAssertEqual(store.uploadPlaceholders(for: album.id).first?.status, .failed)
    }
}

private extension PetAlbumStoreMutationTests {
    static func uploadDraft(fileName: String) -> PetMediaUploadDraft {
        PetMediaUploadDraft(
            fileName: fileName,
            mimeType: "image/jpeg",
            content: Data([1, 2, 3]),
            sourceClient: "ios"
        )
    }

    enum RepositoryEvent: Equatable {
        case uploadMedia(fileName: String)
        case createAlbum(coverAssetID: String?)
        case addAsset(assetID: String, albumID: String)
    }

    // PetAlbumStoreTestRepository 相册 Store 测试仓库
    // 核心职责：
    // - 返回固定相册和照片数据
    // - 记录 Store 发起的后端命令语义
    final class PetAlbumStoreTestRepository: PetAlbumRepository {
        var recordedEvents: [RepositoryEvent] = []
        var onUploadProgressSent: (() -> Void)?
        var uploadError: MHBAPIError?
        var listAssetItems: [PetAlbumDTO.AssetData] = []
        private var uploadCount = 0

        func listAlbums(
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
            draft: PetAlbumCreateDraft,
            currentUserID: String
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
            recordedEvents.append(.createAlbum(coverAssetID: draft.coverAssetID))
            return MHBAPIResponse(
                success: true,
                code: "pet_album.created",
                message: "相册已创建",
                data: Self.albumData(
                    title: draft.normalizedName,
                    isPinned: false,
                    coverAssetID: draft.coverAssetID,
                    coverURL: draft.coverAssetID == nil ? nil : "/media/uploaded.jpg",
                    photoCount: 0
                )
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
                data: PetAlbumDTO.AssetListData(items: listAssetItems, nextCursor: nil)
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

        func uploadAlbumMedia(
            draft: PetMediaUploadDraft,
            currentUserID: String,
            onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
            recordedEvents.append(.uploadMedia(fileName: draft.fileName))
            onUploadProgress(0.5)
            onUploadProgressSent?()
            if let uploadError {
                throw uploadError
            }
            uploadCount += 1
            let uploadedAssetID = "asset-uploaded-\(uploadCount)"
            return MHBAPIResponse(
                success: true,
                code: "pet_album_media.uploaded",
                message: "媒资已上传",
                data: PetMediaUploadResult(
                    asset: PetMediaAsset(
                        id: uploadedAssetID,
                        url: "/media/uploaded.jpg",
                        uploadedByUserID: currentUserID,
                        ownerPetID: nil,
                        usageKind: .albumPhoto,
                        sourceClient: draft.sourceClient,
                        originalFileName: draft.fileName,
                        mimeType: draft.mimeType,
                        byteSize: draft.content.count,
                        sha256Hex: "sha-uploaded",
                        bucket: "media",
                        objectKey: "users/user-1/albums/\(uploadedAssetID)/original.jpg",
                        status: .uploaded,
                        width: 1200,
                        height: 900,
                        createdAt: "2026-07-01T12:00:00Z",
                        updatedAt: "2026-07-01T12:00:00Z"
                    ),
                    binding: nil
                )
            )
        }

        func addAsset(
            albumID: String,
            assetID: String,
            caption: String?,
            currentUserID: String
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AssetData> {
            recordedEvents.append(.addAsset(assetID: assetID, albumID: albumID))
            let assetIndex = recordedEvents.compactMap { event in
                if case .addAsset = event { return event }
                return nil
            }.count
            return MHBAPIResponse(
                success: true,
                code: "pet_album.asset_added",
                message: "照片已加入相册",
                data: PetAlbumDTO.AssetData(
                    id: "album-asset-\(assetIndex)",
                    albumID: albumID,
                    petID: nil,
                    assetID: assetID,
                    assetURL: "/media/uploaded-\(assetIndex).jpg",
                    sha256Hex: "sha-uploaded",
                    addedByUserID: currentUserID,
                    caption: caption,
                    width: 1200,
                    height: 900,
                    sortTakenAt: "2026-07-01T12:00:00Z",
                    removedAt: nil,
                    createdAt: "2026-07-01T12:00:00Z",
                    updatedAt: "2026-07-01T12:00:00Z"
                )
            )
        }

        private static func albumData(
            title: String = "成长记录",
            isPinned: Bool,
            coverAssetID: String? = nil,
            coverURL: String? = "/media/cover.jpg",
            photoCount: Int
        ) -> PetAlbumDTO.AlbumData {
            PetAlbumDTO.AlbumData(
                id: "album",
                petID: nil,
                ownerUserID: "user-1",
                title: title,
                description: nil,
                isPrivate: false,
                isPinned: isPinned,
                coverAssetID: coverAssetID,
                coverURL: coverURL,
                photoCount: photoCount,
                archivedAt: nil,
                createdAt: "2026-07-01T12:00:00Z",
                updatedAt: "2026-07-03T12:00:00Z"
            )
        }
    }
}
