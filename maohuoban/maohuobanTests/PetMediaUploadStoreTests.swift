import XCTest
@testable import maohuoban

// PetMediaUploadStoreTests 宠物媒体上传 Store 测试
// 核心职责：
// - 验证添加和编辑档案共用 pending 上传状态
// - 固化已上传资产绑定入口
@MainActor
final class PetMediaUploadStoreTests: PetMediaUploadStoreTestCase {
    func testUploadAvatarStoresUploadedAssetForCreateBinding() async {
        let repository = CapturingPetMediaUploadRepository()
        repository.uploadPendingAvatarResult = .success(Self.mediaUploadResponse(usageKind: .avatar))
        let store = PetMediaUploadStore(repository: repository)

        let didUpload = await store.uploadAvatar(
            draft: PetMediaUploadDraft(
                fileName: "avatar.jpg",
                mimeType: "image/jpeg",
                content: Data("avatar-content".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertTrue(didUpload)
        XCTAssertEqual(store.avatarState.assetID, "asset-1")
        XCTAssertEqual(store.uploadedBindings.avatarAssetID, "asset-1")
        XCTAssertEqual(repository.callOrder, ["uploadPendingAvatar"])
        XCTAssertEqual(repository.receivedAvatarDraft?.fileName, "avatar.jpg")
        XCTAssertEqual(repository.receivedAvatarUserID, "user-1")
        XCTAssertEqual(repository.observedProgressValues, [0.25, 1.0])
    }

    func testUploadBackgroundLivePhotoStoresUploadedAssetForCreateBinding() async {
        let repository = CapturingPetMediaUploadRepository()
        repository.uploadPendingBackgroundLivePhotoResult = .success(Self.mediaUploadResponse(usageKind: .backgroundLivePhoto))
        let store = PetMediaUploadStore(repository: repository)

        let didUpload = await store.uploadBackgroundLivePhoto(
            draft: PetLivePhotoUploadDraft(
                still: PetMediaUploadDraft(
                    fileName: "background.heic",
                    mimeType: "image/heic",
                    content: Data("still-content".utf8),
                    sourceClient: "ios"
                ),
                pairedVideo: PetMediaUploadDraft(
                    fileName: "background.mov",
                    mimeType: "video/quicktime",
                    content: Data("video-content".utf8),
                    sourceClient: "ios"
                )
            ),
            currentUserID: "user-1"
        )

        XCTAssertTrue(didUpload)
        XCTAssertEqual(store.backgroundState.assetID, "asset-1")
        XCTAssertEqual(store.uploadedBindings.backgroundAssetID, "asset-1")
        XCTAssertEqual(repository.callOrder, ["uploadPendingBackgroundLivePhoto"])
        XCTAssertEqual(repository.receivedLivePhotoDraft?.still.fileName, "background.heic")
        XCTAssertEqual(repository.receivedLivePhotoDraft?.pairedVideo.fileName, "background.mov")
        XCTAssertEqual(repository.receivedLivePhotoUserID, "user-1")
        XCTAssertEqual(repository.observedProgressValues, [0.5, 1.0])
    }

    func testBindUploadedMediaUsesSharedBindingEndpointForEditMode() async {
        let repository = CapturingPetMediaUploadRepository()
        repository.bindUploadedMediaResult = .success(Self.mediaUploadResponse(usageKind: .backgroundImage))
        let store = PetMediaUploadStore(repository: repository)

        let didBind = await store.bindUploadedMedia(
            petID: "pet-1",
            assetID: "asset-1",
            currentUserID: "user-1"
        )

        XCTAssertTrue(didBind)
        XCTAssertEqual(repository.callOrder, ["bindUploadedMedia"])
        XCTAssertEqual(repository.receivedBindPetID, "pet-1")
        XCTAssertEqual(repository.receivedBindAssetID, "asset-1")
        XCTAssertEqual(repository.receivedBindUserID, "user-1")
    }
}
