import XCTest
@testable import maohuoban

// MerchantAvailableStatusStoreTests 商家可售发布 Store 测试
// 核心职责：
// - 验证待发布候选宠物加载状态流
// - 固化发布可售状态的商家、宠物、用户上下文和草稿参数
@MainActor
final class MerchantAvailableStatusStoreTests: XCTestCase {
    func testLoadCandidatesTransitionsToLoadedAndPassesContext() async {
        let repository = CapturingMerchantAvailableStatusRepository()
        repository.listResult = .success(
            MHBAPIResponse(
                success: true,
                code: "merchant.pets_loaded",
                message: "商家宠物列表已加载",
                data: MerchantPetList(
                    merchantID: "merchant-1",
                    status: .needsRecord,
                    pets: [Self.makePet(status: .needsRecord)]
                )
            )
        )
        let store = MerchantAvailableStatusStore(repository: repository)

        await store.loadCandidates(merchantID: "merchant-1", currentUserID: "user-1")

        XCTAssertEqual(store.phase, .loaded([Self.makePet(status: .needsRecord)]))
        XCTAssertEqual(repository.receivedListMerchantID, "merchant-1")
        XCTAssertEqual(repository.receivedListStatus, .needsRecord)
        XCTAssertEqual(repository.receivedListUserID, "user-1")
    }

    func testPublishTransitionsToPublishedAndPassesContext() async {
        let repository = CapturingMerchantAvailableStatusRepository()
        let publication = MerchantAvailableStatusPublication(
            pet: Self.makePet(status: .available),
            event: PetEventDetail(
                id: "event-1",
                petID: "pet-1",
                litterID: nil,
                kind: .merchant,
                subkind: "available_status",
                title: "已发布可售状态",
                summary: "已完成基础健康记录，可预约到店看猫。",
                visibility: .buyerVisible,
                occurredAt: "2026-06-14T10:00:00Z",
                recordRevision: 1,
                eventPayload: nil
            )
        )
        repository.publishResult = .success(
            MHBAPIResponse(
                success: true,
                code: "merchant.available_status_published",
                message: "可售状态已发布",
                data: publication
            )
        )
        let store = MerchantAvailableStatusStore(repository: repository)

        await store.publish(
            merchantID: "merchant-1",
            petID: "pet-1",
            draft: MerchantAvailableStatusDraft(
                summary: "已完成基础健康记录，可预约到店看猫。",
                occurredAt: "2026-06-14T10:00:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .published(publication))
        XCTAssertEqual(store.successMessage, "可售状态已发布")
        XCTAssertEqual(repository.receivedPublishMerchantID, "merchant-1")
        XCTAssertEqual(repository.receivedPublishPetID, "pet-1")
        XCTAssertEqual(repository.receivedPublishDraft?.summary, "已完成基础健康记录，可预约到店看猫。")
        XCTAssertEqual(repository.receivedPublishUserID, "user-1")
    }

    func testPublishWithoutUserContextFailsBeforeRepositoryCall() async {
        let repository = CapturingMerchantAvailableStatusRepository()
        let store = MerchantAvailableStatusStore(repository: repository)

        await store.publish(
            merchantID: "merchant-1",
            petID: "pet-1",
            draft: MerchantAvailableStatusDraft(
                summary: "已完成基础健康记录，可预约到店看猫。",
                occurredAt: "2026-06-14T10:00:00Z"
            ),
            currentUserID: nil
        )

        XCTAssertEqual(store.phase, .failed("请先登录"))
        XCTAssertNil(repository.receivedPublishMerchantID)
    }

    private static func makePet(status: MerchantPetStatus) -> MerchantManagedPet {
        MerchantManagedPet(
            id: "pet-1",
            ownerUserID: nil,
            merchantID: "merchant-1",
            name: "小白",
            species: .cat,
            breed: "布偶猫",
            sex: .unknown,
            birthday: "2026-03-18",
            managedStatus: status,
            sourceKind: .litterBirth,
            createdAt: "2026-06-13T09:20:00Z",
            updatedAt: "2026-06-14T10:00:00Z"
        )
    }
}

// CapturingMerchantAvailableStatusRepository 商家可售发布测试仓库
// 核心职责：
// - 捕获 Store 传入的候选加载和发布参数
// - 返回测试指定响应
@MainActor
private final class CapturingMerchantAvailableStatusRepository: MerchantRepository {
    var listResult: Result<MHBAPIResponse<MerchantPetList>, MHBAPIError> = .failure(.invalidResponse)
    var publishResult: Result<MHBAPIResponse<MerchantAvailableStatusPublication>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var receivedListMerchantID: String?
    private(set) var receivedListStatus: MerchantPetStatus?
    private(set) var receivedListUserID: String?
    private(set) var receivedPublishMerchantID: String?
    private(set) var receivedPublishPetID: String?
    private(set) var receivedPublishDraft: MerchantAvailableStatusDraft?
    private(set) var receivedPublishUserID: String?

    func listPets(
        merchantID: String,
        status: MerchantPetStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantPetList> {
        receivedListMerchantID = merchantID
        receivedListStatus = status
        receivedListUserID = currentUserID
        switch listResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func createPet(
        merchantID: String,
        draft: MerchantPetDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantManagedPet> {
        throw .invalidResponse
    }

    func loadLitterDetail(
        merchantID: String,
        litterID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantLitterDetail> {
        throw .invalidResponse
    }

    func publishAvailableStatus(
        merchantID: String,
        petID: String,
        draft: MerchantAvailableStatusDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantAvailableStatusPublication> {
        receivedPublishMerchantID = merchantID
        receivedPublishPetID = petID
        receivedPublishDraft = draft
        receivedPublishUserID = currentUserID
        switch publishResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
