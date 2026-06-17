import XCTest
@testable import maohuoban

// PetWriteStoreTests 宠物写入 Store 测试
// 核心职责：
// - 验证创建宠物与记录事件状态流
// - 固化当前用户上下文传递行为
@MainActor
final class PetWriteStoreTests: XCTestCase {
    func testCreatePetTransitionsToCreatedAndPassesUserContext() async {
        let repository = CapturingPetRepository()
        repository.createPetResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.created",
                message: "宠物档案已创建",
                data: PetProfileSummary(
                    id: "pet-1",
                    ownerUserID: "user-1",
                    name: "糯米",
                    species: .dog,
                    breed: "比熊犬",
                    sex: .female,
                    birthday: "2024-04-01"
                )
            )
        )
        let store = PetWriteStore(repository: repository)

        await store.createPet(
            draft: PetProfileDraft(
                name: "糯米",
                species: .dog,
                breed: "比熊犬",
                sex: .female,
                birthday: "2024-04-01"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .createdPet("pet-1"))
        XCTAssertEqual(store.successMessage, "宠物档案已创建")
        XCTAssertEqual(repository.receivedCreateUserID, "user-1")
        XCTAssertEqual(repository.receivedCreateDraft?.name, "糯米")
    }

    func testCreatePetWithoutNameFailsBeforeRepositoryCall() async {
        let repository = CapturingPetRepository()
        let store = PetWriteStore(repository: repository)

        await store.createPet(
            draft: PetProfileDraft(
                name: "  ",
                species: .cat,
                breed: "",
                sex: .unknown,
                birthday: ""
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .failed("请输入宠物名字"))
        XCTAssertNil(repository.receivedCreateDraft)
    }

    func testRecordEventTransitionsToRecordedAndPassesUserContext() async {
        let repository = CapturingPetRepository()
        repository.createEventResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.event_created",
                message: "宠物事件已记录",
                data: PetEventSummary(
                    id: "event-1",
                    petID: "pet-1",
                    kind: .health,
                    subkind: "weight",
                    title: "体重记录",
                    summary: "5.2kg，较上次稳定",
                    visibility: .private,
                    occurredAt: "2026-06-13T09:20:00Z",
                    recordRevision: 1
                )
            )
        )
        let store = PetWriteStore(repository: repository)

        await store.createEvent(
            petID: "pet-1",
            draft: PetEventDraft(
                kind: .health,
                subkind: "weight",
                title: "体重记录",
                summary: "5.2kg，较上次稳定",
                visibility: .private,
                occurredAt: "2026-06-13T09:20:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .recordedEvent("event-1"))
        XCTAssertEqual(store.successMessage, "宠物事件已记录")
        XCTAssertEqual(repository.receivedEventPetID, "pet-1")
        XCTAssertEqual(repository.receivedEventUserID, "user-1")
    }

    func testImportTradePetTransitionsToImportedAndPassesUserContext() async {
        let repository = CapturingPetRepository()
        repository.importTradePetResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.trade_imported",
                message: "交易宠物已导入",
                data: TradePetImportResult(
                    pet: PetProfileSummary(
                        id: "pet-1",
                        ownerUserID: "user-1",
                        name: "奶盖",
                        species: .cat,
                        breed: "布偶",
                        sex: .female,
                        birthday: "2024-03-20"
                    ),
                    event: PetEventSummary(
                        id: "event-1",
                        petID: "pet-1",
                        kind: .trade,
                        subkind: "trade_imported",
                        title: "交易宠物导入",
                        summary: "线下交易完成，已完成基础体检",
                        visibility: .private,
                        occurredAt: "2026-06-13T10:00:00Z",
                        recordRevision: 1
                    )
                )
            )
        )
        let store = PetWriteStore(repository: repository)

        await store.importTradePet(
            draft: TradePetImportDraft(
                name: "奶盖",
                species: .cat,
                breed: "布偶",
                sex: .female,
                birthday: "2024-03-20",
                sellerName: "安心猫舍",
                tradeReference: "offline-contract-001",
                summary: "线下交易完成，已完成基础体检",
                occurredAt: "2026-06-13T10:00:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .importedTradePet("pet-1"))
        XCTAssertEqual(store.successMessage, "交易宠物已导入")
        XCTAssertEqual(repository.receivedImportUserID, "user-1")
        XCTAssertEqual(repository.receivedImportDraft?.sellerName, "安心猫舍")
    }

    func testImportTradePetWithoutSellerFailsBeforeRepositoryCall() async {
        let repository = CapturingPetRepository()
        let store = PetWriteStore(repository: repository)

        await store.importTradePet(
            draft: TradePetImportDraft(
                name: "奶盖",
                species: .cat,
                breed: "",
                sex: .unknown,
                birthday: "",
                sellerName: "  ",
                tradeReference: "",
                summary: "",
                occurredAt: "2026-06-13T10:00:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .failed("请输入交易来源方"))
        XCTAssertNil(repository.receivedImportDraft)
    }

    func testUpdatePetTransitionsToUpdatedAndPassesUserContext() async {
        let repository = CapturingPetRepository()
        repository.updatePetResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.updated",
                message: "宠物档案已更新",
                data: PetProfileSummary(
                    id: "pet-1",
                    ownerUserID: "user-1",
                    name: "糯米",
                    species: .dog,
                    breed: "",
                    sex: .female,
                    birthday: "2024-04-01",
                    microchipNumber: "901156260000001",
                    arrivalDate: "2024-06-16",
                    weightGrams: 4800,
                    neuterStatus: .neutered,
                    personalityTags: ["亲人"],
                    note: "喜欢晒太阳"
                )
            )
        )
        let store = PetWriteStore(repository: repository)

        await store.updatePet(
            petID: "pet-1",
            draft: PetProfileUpdateDraft(
                name: "糯米",
                species: .dog,
                breed: "",
                sex: .female,
                birthday: "2024-04-01",
                microchipNumber: "901156260000001",
                arrivalDate: "2024-06-16",
                weightGrams: 4800,
                neuterStatus: .neutered,
                personalityTags: ["亲人"],
                note: "喜欢晒太阳"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .updatedPet("pet-1"))
        XCTAssertEqual(store.successMessage, "宠物档案已更新")
        XCTAssertEqual(repository.receivedUpdatePetID, "pet-1")
        XCTAssertEqual(repository.receivedUpdateUserID, "user-1")
        XCTAssertEqual(repository.receivedUpdateDraft?.weightGrams, 4800)
    }

    func testUploadAvatarTransitionsToUploadedAndPassesUserContext() async {
        let repository = CapturingPetRepository()
        repository.uploadAvatarResult = .success(Self.mediaUploadResponse(usageKind: .avatar))
        let store = PetWriteStore(repository: repository)

        await store.uploadAvatar(
            petID: "pet-1",
            draft: PetMediaUploadDraft(
                fileName: "avatar.jpg",
                mimeType: "image/jpeg",
                content: Data("avatar-content".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .uploadedAvatar("asset-1"))
        XCTAssertEqual(repository.receivedAvatarPetID, "pet-1")
        XCTAssertEqual(repository.receivedAvatarUserID, "user-1")
        XCTAssertEqual(repository.receivedAvatarDraft?.fileName, "avatar.jpg")
    }

    func testUploadBackgroundImageTransitionsToUploadedAndPassesUserContext() async {
        let repository = CapturingPetRepository()
        repository.uploadBackgroundImageResult = .success(Self.mediaUploadResponse(usageKind: .backgroundImage))
        let store = PetWriteStore(repository: repository)

        await store.uploadBackgroundImage(
            petID: "pet-1",
            draft: PetMediaUploadDraft(
                fileName: "background.jpg",
                mimeType: "image/jpeg",
                content: Data("background-content".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .uploadedBackground("asset-1"))
        XCTAssertEqual(store.mediaDerivativeMessage, "已生成主题色 #FF0000 和 1 个派生资源")
        XCTAssertEqual(repository.receivedBackgroundImagePetID, "pet-1")
        XCTAssertEqual(repository.receivedBackgroundImageUserID, "user-1")
        XCTAssertEqual(repository.receivedBackgroundImageDraft?.mimeType, "image/jpeg")
    }

    func testUploadBackgroundVideoTransitionsToUploadedAndPassesUserContext() async {
        let repository = CapturingPetRepository()
        repository.uploadBackgroundVideoResult = .success(Self.mediaUploadResponse(usageKind: .backgroundVideo))
        let store = PetWriteStore(repository: repository)

        await store.uploadBackgroundVideo(
            petID: "pet-1",
            draft: PetMediaUploadDraft(
                fileName: "background.mp4",
                mimeType: "video/mp4",
                content: Data("background-video-content".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .uploadedBackground("asset-1"))
        XCTAssertEqual(store.mediaDerivativeMessage, "已生成封面帧、主题色 #FF0000 和 2 个派生资源")
        XCTAssertEqual(repository.receivedBackgroundVideoPetID, "pet-1")
        XCTAssertEqual(repository.receivedBackgroundVideoUserID, "user-1")
        XCTAssertEqual(repository.receivedBackgroundVideoDraft?.mimeType, "video/mp4")
    }

    func testDeletePetTransitionsToDeletedAndPassesUserContext() async {
        let repository = CapturingPetRepository()
        repository.deletePetResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.deleted",
                message: "宠物档案已删除",
                data: PetProfileSummary(
                    id: "pet-1",
                    ownerUserID: "user-1",
                    name: "糯米",
                    species: .dog,
                    breed: "",
                    sex: .female,
                    birthday: "2024-04-01",
                    deletedAt: "2026-06-17T00:00:00Z",
                    deleteRequestedByUserID: "user-1",
                    recoverableUntil: "2026-07-17T00:00:00Z",
                    deleteReason: "用户主动删除"
                )
            )
        )
        let store = PetWriteStore(repository: repository)

        await store.deletePet(
            petID: "pet-1",
            reason: "用户主动删除",
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .deletedPet("pet-1"))
        XCTAssertEqual(store.successMessage, "宠物档案已删除")
        XCTAssertEqual(repository.receivedDeletePetID, "pet-1")
        XCTAssertEqual(repository.receivedDeleteReason, "用户主动删除")
        XCTAssertEqual(repository.receivedDeleteUserID, "user-1")
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
                    ownerPetID: "pet-1",
                    usageKind: usageKind,
                    sourceClient: "ios",
                    originalFileName: "media",
                    mimeType: "image/jpeg",
                    byteSize: 16,
                    sha256Hex: "hash",
                    bucket: "maohuoban-pet-media",
                    objectKey: "pets/pet-1/media",
                    status: .bound,
                    createdAt: "2026-06-17T00:00:00Z",
                    updatedAt: "2026-06-17T00:00:00Z"
                ),
                binding: PetMediaBinding(
                    id: "binding-1",
                    assetID: "asset-1",
                    petID: "pet-1",
                    usageKind: usageKind,
                    status: .active,
                    boundByUserID: "user-1",
                    boundAt: "2026-06-17T00:00:00Z",
                    createdAt: "2026-06-17T00:00:00Z"
                ),
                derivatives: [
                    PetMediaDerivative(
                        id: "derivative-cover",
                        parentAssetID: "asset-1",
                        derivativeKind: .videoCoverFrame,
                        bucket: "maohuoban-pet-media",
                        objectKey: "pets/pet-1/cover-frame.png",
                        mimeType: "image/png",
                        byteSize: 12,
                        sha256Hex: "hash",
                        metadata: PetMediaDerivativeMetadata(width: 512, height: 512),
                        createdAt: "2026-06-17T00:00:00Z"
                    ),
                    PetMediaDerivative(
                        id: "derivative-theme",
                        parentAssetID: "asset-1",
                        derivativeKind: .themeColorFrame,
                        bucket: "maohuoban-pet-media",
                        objectKey: "pets/pet-1/theme-color.json",
                        mimeType: "application/json",
                        byteSize: 24,
                        sha256Hex: "hash",
                        metadata: PetMediaDerivativeMetadata(themeColorHex: "#FF0000"),
                        createdAt: "2026-06-17T00:00:00Z"
                    )
                ].filter { derivative in
                    usageKind == .backgroundVideo || derivative.derivativeKind == .themeColorFrame
                }
            )
        )
    }
}

// CapturingPetRepository 宠物写入测试仓库
// 核心职责：
// - 捕获 Store 传入的请求参数
// - 返回测试指定结果
@MainActor
private final class CapturingPetRepository: PetRepository {
    var createPetResult: Result<MHBAPIResponse<PetProfileSummary>, MHBAPIError> = .failure(.invalidResponse)
    var createEventResult: Result<MHBAPIResponse<PetEventSummary>, MHBAPIError> = .failure(.invalidResponse)
    var importTradePetResult: Result<MHBAPIResponse<TradePetImportResult>, MHBAPIError> = .failure(.invalidResponse)
    var updatePetResult: Result<MHBAPIResponse<PetProfileSummary>, MHBAPIError> = .failure(.invalidResponse)
    var uploadAvatarResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadBackgroundImageResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadBackgroundVideoResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var deletePetResult: Result<MHBAPIResponse<PetProfileSummary>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var receivedCreateDraft: PetProfileDraft?
    private(set) var receivedCreateUserID: String?
    private(set) var receivedEventPetID: String?
    private(set) var receivedEventDraft: PetEventDraft?
    private(set) var receivedEventUserID: String?
    private(set) var receivedImportDraft: TradePetImportDraft?
    private(set) var receivedImportUserID: String?
    private(set) var receivedUpdatePetID: String?
    private(set) var receivedUpdateDraft: PetProfileUpdateDraft?
    private(set) var receivedUpdateUserID: String?
    private(set) var receivedAvatarPetID: String?
    private(set) var receivedAvatarDraft: PetMediaUploadDraft?
    private(set) var receivedAvatarUserID: String?
    private(set) var receivedBackgroundImagePetID: String?
    private(set) var receivedBackgroundImageDraft: PetMediaUploadDraft?
    private(set) var receivedBackgroundImageUserID: String?
    private(set) var receivedBackgroundVideoPetID: String?
    private(set) var receivedBackgroundVideoDraft: PetMediaUploadDraft?
    private(set) var receivedBackgroundVideoUserID: String?
    private(set) var receivedDeletePetID: String?
    private(set) var receivedDeleteReason: String?
    private(set) var receivedDeleteUserID: String?

    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        receivedCreateDraft = draft
        receivedCreateUserID = currentUserID
        switch createPetResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary> {
        receivedEventPetID = petID
        receivedEventDraft = draft
        receivedEventUserID = currentUserID
        switch createEventResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        throw .invalidResponse
    }

    func updatePet(
        petID: String,
        draft: PetProfileUpdateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        receivedUpdatePetID = petID
        receivedUpdateDraft = draft
        receivedUpdateUserID = currentUserID
        switch updatePetResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadAvatar(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        receivedAvatarPetID = petID
        receivedAvatarDraft = draft
        receivedAvatarUserID = currentUserID
        switch uploadAvatarResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadBackgroundImage(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        receivedBackgroundImagePetID = petID
        receivedBackgroundImageDraft = draft
        receivedBackgroundImageUserID = currentUserID
        switch uploadBackgroundImageResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadBackgroundVideo(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        receivedBackgroundVideoPetID = petID
        receivedBackgroundVideoDraft = draft
        receivedBackgroundVideoUserID = currentUserID
        switch uploadBackgroundVideoResult {
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
        receivedDeletePetID = petID
        receivedDeleteReason = reason
        receivedDeleteUserID = currentUserID
        switch deletePetResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<TradePetImportResult> {
        receivedImportDraft = draft
        receivedImportUserID = currentUserID
        switch importTradePetResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
