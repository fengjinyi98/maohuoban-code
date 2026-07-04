import XCTest
@testable import maohuoban

// PetEventDetailStoreTests 宠物事件详情 Store 测试
// 核心职责：
// - 验证事件详情加载状态流
// - 固化当前用户和事件 ID 参数传递
// - 验证详情页删除事件的单一状态流
@MainActor
final class PetEventDetailStoreTests: XCTestCase {
    func testLoadTransitionsToLoadedAndPassesContext() async {
        let repository = CapturingPetEventDetailRepository()
        let event = PetEventDetail(
            id: "event-1",
            petID: "pet-1",
            litterID: nil,
            kind: .health,
            subkind: "weight",
            title: "体重记录",
            summary: "5.2kg，较上次稳定",
            visibility: .private,
            occurredAt: "2026-06-13T09:20:00Z",
            recordRevision: 1,
            eventPayload: nil
        )
        repository.eventResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.event_loaded",
                message: "宠物事件已加载",
                data: event
            )
        )
        let store = PetEventDetailStore(repository: repository)

        await store.load(eventID: "event-1", currentUserID: "user-1")

        XCTAssertEqual(store.phase, .loaded(event))
        XCTAssertEqual(repository.receivedEventID, "event-1")
        XCTAssertEqual(repository.receivedUserID, "user-1")
    }

    func testLoadWithoutUserContextFailsBeforeRepositoryCall() async {
        let repository = CapturingPetEventDetailRepository()
        let store = PetEventDetailStore(repository: repository)

        await store.load(eventID: "event-1", currentUserID: nil)

        XCTAssertEqual(store.phase, .failed("请先登录"))
        XCTAssertNil(repository.receivedEventID)
    }

    func testDeleteTransitionsToDeletedAndPassesContext() async {
        let repository = CapturingPetEventDetailRepository()
        repository.deleteEventResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.event_deleted",
                message: "宠物事件已删除",
                data: DeletedPetEvent(id: "event-1", deleted: true)
            )
        )
        let store = PetEventDetailStore(repository: repository)

        let didDelete = await store.delete(eventID: "event-1", currentUserID: "user-1")

        XCTAssertTrue(didDelete)
        XCTAssertEqual(store.phase, .deleted("event-1"))
        XCTAssertEqual(repository.receivedDeleteEventID, "event-1")
        XCTAssertEqual(repository.receivedDeleteUserID, "user-1")
    }

    func testDeleteWithoutUserContextFailsBeforeRepositoryCall() async {
        let repository = CapturingPetEventDetailRepository()
        let store = PetEventDetailStore(repository: repository)

        let didDelete = await store.delete(eventID: "event-1", currentUserID: nil)

        XCTAssertFalse(didDelete)
        XCTAssertEqual(store.phase, .failed("请先登录"))
        XCTAssertNil(repository.receivedDeleteEventID)
    }
}

// CapturingPetEventDetailRepository 宠物事件详情测试仓库
// 核心职责：
// - 捕获 Store 传入的事件详情查询参数
// - 返回测试指定响应
@MainActor
private final class CapturingPetEventDetailRepository: PetRepository {
    var eventResult: Result<MHBAPIResponse<PetEventDetail>, MHBAPIError> = .failure(.invalidResponse)
    var deleteEventResult: Result<MHBAPIResponse<DeletedPetEvent>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var receivedEventID: String?
    private(set) var receivedUserID: String?
    private(set) var receivedDeleteEventID: String?
    private(set) var receivedDeleteUserID: String?

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

    func updateEvent(
        eventID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
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
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func uploadPendingBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func uploadPendingBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func uploadPendingBackgroundLivePhoto(
        draft: PetLivePhotoUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func uploadEventAttachment(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
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
        receivedEventID = eventID
        receivedUserID = currentUserID
        switch eventResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func loadTimeline(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetTimeline> {
        throw .invalidResponse
    }

    func deleteEvent(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetEvent> {
        receivedDeleteEventID = eventID
        receivedDeleteUserID = currentUserID
        switch deleteEventResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func listWeightRecords(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecordList> {
        throw .invalidResponse
    }

    func createWeightRecord(
        petID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        throw .invalidResponse
    }

    func loadWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        throw .invalidResponse
    }

    func updateWeightRecord(
        recordID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        throw .invalidResponse
    }

    func deleteWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetWeightRecord> {
        throw .invalidResponse
    }

    func loadIdentityContext(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetIdentityContext> {
        throw MHBAPIError.transport("Phase 1 placeholder")
    }

}
