import XCTest
import MaohuobanDiagnostics
@testable import maohuoban

// PetMediaUploadStoreTests 宠物媒体上传 Store 测试
// 核心职责：
// - 验证添加和编辑档案共用 pending 上传状态
// - 固化已上传资产绑定入口
@MainActor
final class PetMediaUploadStoreTests: XCTestCase {
    override func tearDown() {
        Task {
            await Diagnostics.uninstall()
        }
        super.tearDown()
    }

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

    func testUploadBackgroundVideoRecordsDiagnosticsEvents() async throws {
        let diagnostics = try await Self.installDiagnostics()
        let repository = CapturingPetMediaUploadRepository()
        repository.uploadPendingBackgroundVideoResult = .success(Self.mediaUploadResponse(usageKind: .backgroundVideo))
        let store = PetMediaUploadStore(repository: repository)

        let didUpload = await store.uploadBackgroundVideo(
            draft: PetMediaUploadDraft(
                fileName: "background.mov",
                mimeType: "video/mp4",
                content: Data("video-content".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertTrue(didUpload)
        let events = try await diagnostics.readEvents()
        XCTAssertTrue(events.contains {
            $0.kind == .analytics
                && $0.message == "pet.media_upload_started"
                && $0.metadata["media_slot"] == "backgroundVideo"
                && $0.metadata["mime_type"] == "video/mp4"
        })
        XCTAssertTrue(events.contains {
            $0.kind == .analytics
                && $0.message == "pet.media_upload_succeeded"
                && $0.metadata["media_slot"] == "backgroundVideo"
                && $0.metadata["asset_id_prefix"] == "asset-1"
                && $0.metadata["width"] == 1280
                && $0.metadata["height"] == 720
        })
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

    func testBindUploadedMediaRecordsDiagnosticsEvent() async throws {
        let diagnostics = try await Self.installDiagnostics()
        let repository = CapturingPetMediaUploadRepository()
        repository.bindUploadedMediaResult = .success(Self.mediaUploadResponse(usageKind: .backgroundImage))
        let store = PetMediaUploadStore(repository: repository)

        let didBind = await store.bindUploadedMedia(
            petID: "pet-1",
            assetID: "asset-1",
            currentUserID: "user-1"
        )

        XCTAssertTrue(didBind)
        let events = try await diagnostics.readEvents()
        XCTAssertTrue(events.contains {
            $0.kind == .analytics
                && $0.message == "pet.media_bind_succeeded"
                && $0.metadata["pet_id_prefix"] == "pet-1"
                && $0.metadata["asset_id_prefix"] == "asset-1"
        })
    }

    private static func mediaUploadResponse(
        usageKind: PetMediaUsageKind
    ) -> MHBAPIResponse<PetMediaUploadResult> {
        MHBAPIResponse(
            success: true,
            code: "pet.media_uploaded",
            message: "媒体已上传",
            data: PetMediaUploadResult(
                asset: PetMediaAsset(
                    id: "asset-1",
                    uploadedByUserID: "user-1",
                    ownerPetID: nil,
                    usageKind: usageKind,
                    sourceClient: "ios",
                    originalFileName: "media",
                    mimeType: "image/jpeg",
                    byteSize: 16,
                    sha256Hex: "hash",
                    bucket: "maohuoban-pet-media",
                    objectKey: "pet-media/media",
                    status: .uploaded,
                    width: 1280,
                    height: 720,
                    createdAt: "2026-06-17T00:00:00Z",
                    updatedAt: "2026-06-17T00:00:00Z"
                ),
                binding: nil
            )
        )
    }

    private static func installDiagnostics() async throws -> DiagnosticsRuntime {
        await Diagnostics.uninstall()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("maohuoban-media-upload-tests-\(UUID().uuidString)", isDirectory: true)
        return try await Diagnostics.install(
            DiagnosticsConfiguration(
                serviceName: "maohuoban-ios-tests",
                environment: "test",
                storageDirectory: root
            )
        )
    }
}

// CapturingPetMediaUploadRepository 宠物媒体上传测试仓库
// 核心职责：
// - 捕获媒体上传 Store 的请求参数
// - 返回测试指定响应
@MainActor
private final class CapturingPetMediaUploadRepository: PetRepository {
    var uploadPendingAvatarResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadPendingBackgroundImageResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadPendingBackgroundVideoResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadPendingBackgroundLivePhotoResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var bindUploadedMediaResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var callOrder: [String] = []
    private(set) var receivedAvatarDraft: PetMediaUploadDraft?
    private(set) var receivedAvatarUserID: String?
    private(set) var receivedLivePhotoDraft: PetLivePhotoUploadDraft?
    private(set) var receivedLivePhotoUserID: String?
    private(set) var receivedBindPetID: String?
    private(set) var receivedBindAssetID: String?
    private(set) var receivedBindUserID: String?
    private(set) var observedProgressValues: [Double] = []

    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        throw .invalidResponse
    }

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary> {
        throw .invalidResponse
    }

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<TradePetImportResult> {
        throw .invalidResponse
    }

    func updatePet(
        petID: String,
        draft: PetProfileUpdateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        throw .invalidResponse
    }

    func uploadPendingAvatar(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        callOrder.append("uploadPendingAvatar")
        receivedAvatarDraft = draft
        receivedAvatarUserID = currentUserID
        if let onUploadProgress {
            onUploadProgress(0.25)
            observedProgressValues.append(0.25)
            onUploadProgress(1.0)
            observedProgressValues.append(1.0)
        }
        switch uploadPendingAvatarResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadPendingBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        switch uploadPendingBackgroundImageResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadPendingBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        switch uploadPendingBackgroundVideoResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadPendingBackgroundLivePhoto(
        draft: PetLivePhotoUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        callOrder.append("uploadPendingBackgroundLivePhoto")
        receivedLivePhotoDraft = draft
        receivedLivePhotoUserID = currentUserID
        if let onUploadProgress {
            onUploadProgress(0.5)
            observedProgressValues.append(0.5)
            onUploadProgress(1.0)
            observedProgressValues.append(1.0)
        }
        switch uploadPendingBackgroundLivePhotoResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        callOrder.append("bindUploadedMedia")
        receivedBindPetID = petID
        receivedBindAssetID = assetID
        receivedBindUserID = currentUserID
        switch bindUploadedMediaResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func deletePet(
        petID: String,
        reason: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        throw .invalidResponse
    }

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        throw .invalidResponse
    }
}
