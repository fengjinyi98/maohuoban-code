import XCTest
@testable import maohuoban

// MerchantPetsStoreTests 商家宠物列表 Store 测试
// 核心职责：
// - 验证商家宠物列表加载状态流
// - 固化当前用户上下文传递和缺失上下文兜底
@MainActor
final class MerchantPetsStoreTests: XCTestCase {
    func testLoadTransitionsToLoadedAndPassesContext() async {
        let repository = CapturingMerchantRepository()
        let list = MerchantPetList(
            merchantID: "merchant-1",
            status: .available,
            pets: [
                MerchantManagedPet(
                    id: "pet-1",
                    ownerUserID: nil,
                    merchantID: "merchant-1",
                    name: "小橘",
                    species: .cat,
                    breed: "布偶猫",
                    sex: .female,
                    birthday: "2026-03-18",
                    managedStatus: .available,
                    sourceKind: .litterBirth,
                    createdAt: "2026-06-13T09:20:00Z",
                    updatedAt: "2026-06-13T09:20:00Z"
                )
            ]
        )
        repository.result = .success(
            MHBAPIResponse(
                success: true,
                code: "merchant.pets_loaded",
                message: "商家宠物列表已加载",
                data: list
            )
        )
        let store = MerchantPetsStore(repository: repository)

        await store.load(
            merchantID: "merchant-1",
            status: .available,
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .loaded(list))
        XCTAssertEqual(repository.receivedMerchantID, "merchant-1")
        XCTAssertEqual(repository.receivedStatus, .available)
        XCTAssertEqual(repository.receivedUserID, "user-1")
    }

    func testLoadWithoutUserContextFailsBeforeRepositoryCall() async {
        let repository = CapturingMerchantRepository()
        let store = MerchantPetsStore(repository: repository)

        await store.load(
            merchantID: "merchant-1",
            status: .available,
            currentUserID: nil
        )

        XCTAssertEqual(store.phase, .failed("请先登录"))
        XCTAssertNil(repository.receivedMerchantID)
    }
}

// CapturingMerchantRepository 商家测试仓库
// 核心职责：
// - 捕获 Store 传入的商家查询参数
// - 返回测试指定响应
@MainActor
private final class CapturingMerchantRepository: MerchantRepository {
    var result: Result<MHBAPIResponse<MerchantPetList>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var receivedMerchantID: String?
    private(set) var receivedStatus: MerchantPetStatus?
    private(set) var receivedUserID: String?

    func listPets(
        merchantID: String,
        status: MerchantPetStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantPetList> {
        receivedMerchantID = merchantID
        receivedStatus = status
        receivedUserID = currentUserID
        switch result {
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
}
