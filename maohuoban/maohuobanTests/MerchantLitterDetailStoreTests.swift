import XCTest
@testable import maohuoban

// MerchantLitterDetailStoreTests 商家窝次详情 Store 测试
// 核心职责：
// - 验证窝次详情加载状态流
// - 固化当前用户、商家 ID 和窝次 ID 参数传递
@MainActor
final class MerchantLitterDetailStoreTests: XCTestCase {
    func testLoadTransitionsToLoadedAndPassesContext() async {
        let repository = CapturingMerchantLitterRepository()
        let detail = MerchantLitterDetail(
            id: "litter-1",
            merchantID: "merchant-1",
            name: "2026 春季 A 窝",
            species: .cat,
            bornAt: "2026-03-18",
            bornCount: 3,
            aliveCount: 3,
            availableCount: 2,
            status: .active,
            sirePet: nil,
            damPet: nil,
            children: [],
            relationships: [],
            recentEvents: []
        )
        repository.litterResult = .success(
            MHBAPIResponse(
                success: true,
                code: "merchant.litter_loaded",
                message: "窝次详情已加载",
                data: detail
            )
        )
        let store = MerchantLitterDetailStore(repository: repository)

        await store.load(
            merchantID: "merchant-1",
            litterID: "litter-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .loaded(detail))
        XCTAssertEqual(repository.receivedMerchantID, "merchant-1")
        XCTAssertEqual(repository.receivedLitterID, "litter-1")
        XCTAssertEqual(repository.receivedUserID, "user-1")
    }

    func testLoadWithoutUserContextFailsBeforeRepositoryCall() async {
        let repository = CapturingMerchantLitterRepository()
        let store = MerchantLitterDetailStore(repository: repository)

        await store.load(
            merchantID: "merchant-1",
            litterID: "litter-1",
            currentUserID: nil
        )

        XCTAssertEqual(store.phase, .failed("请先登录"))
        XCTAssertNil(repository.receivedMerchantID)
    }
}

// CapturingMerchantLitterRepository 商家窝次详情测试仓库
// 核心职责：
// - 捕获 Store 传入的窝次详情查询参数
// - 返回测试指定响应
@MainActor
private final class CapturingMerchantLitterRepository: MerchantRepository {
    var litterResult: Result<MHBAPIResponse<MerchantLitterDetail>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var receivedMerchantID: String?
    private(set) var receivedLitterID: String?
    private(set) var receivedUserID: String?

    func listPets(
        merchantID: String,
        status: MerchantPetStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantPetList> {
        throw .invalidResponse
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
        receivedMerchantID = merchantID
        receivedLitterID = litterID
        receivedUserID = currentUserID
        switch litterResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
