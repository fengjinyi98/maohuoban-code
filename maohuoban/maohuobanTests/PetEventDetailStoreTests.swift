import XCTest
@testable import maohuoban

// PetEventDetailStoreTests 宠物事件详情 Store 测试
// 核心职责：
// - 验证事件详情加载状态流
// - 固化当前用户和事件 ID 参数传递
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
            recordRevision: 1
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
}

// CapturingPetEventDetailRepository 宠物事件详情测试仓库
// 核心职责：
// - 捕获 Store 传入的事件详情查询参数
// - 返回测试指定响应
@MainActor
private final class CapturingPetEventDetailRepository: PetRepository {
    var eventResult: Result<MHBAPIResponse<PetEventDetail>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var receivedEventID: String?
    private(set) var receivedUserID: String?

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
}
