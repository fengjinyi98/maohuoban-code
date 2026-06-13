import XCTest
@testable import maohuoban

// MerchantPetCreateStoreTests 商家宠物创建 Store 测试
// 核心职责：
// - 验证商家新增宠物提交状态流
// - 固化当前用户、商家 ID 和草稿参数传递
@MainActor
final class MerchantPetCreateStoreTests: XCTestCase {
    func testCreateTransitionsToCreatedAndPassesContext() async {
        let repository = CapturingMerchantCreateRepository()
        let pet = MerchantManagedPet(
            id: "pet-2",
            ownerUserID: nil,
            merchantID: "merchant-1",
            name: "奶糖",
            species: .cat,
            breed: "布偶猫",
            sex: .female,
            birthday: "2026-04-01",
            managedStatus: .needsRecord,
            sourceKind: .merchantManaged,
            createdAt: "2026-06-13T09:20:00Z",
            updatedAt: "2026-06-13T09:20:00Z"
        )
        repository.createResult = .success(
            MHBAPIResponse(
                success: true,
                code: "merchant.pet_created",
                message: "商家宠物已新增",
                data: pet
            )
        )
        let store = MerchantPetCreateStore(repository: repository)

        await store.create(
            merchantID: "merchant-1",
            draft: MerchantPetDraft(
                name: "奶糖",
                species: .cat,
                breed: "布偶猫",
                sex: .female,
                birthday: "2026-04-01",
                managedStatus: .needsRecord
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .created("pet-2"))
        XCTAssertEqual(store.successMessage, "商家宠物已新增")
        XCTAssertEqual(repository.receivedMerchantID, "merchant-1")
        XCTAssertEqual(repository.receivedDraft?.name, "奶糖")
        XCTAssertEqual(repository.receivedUserID, "user-1")
    }

    func testCreateWithoutNameFailsBeforeRepositoryCall() async {
        let repository = CapturingMerchantCreateRepository()
        let store = MerchantPetCreateStore(repository: repository)

        await store.create(
            merchantID: "merchant-1",
            draft: MerchantPetDraft(
                name: " ",
                species: .cat,
                breed: "",
                sex: .unknown,
                birthday: "",
                managedStatus: .needsRecord
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .failed("请输入宠物名字"))
        XCTAssertNil(repository.receivedMerchantID)
    }
}

// CapturingMerchantCreateRepository 商家创建测试仓库
// 核心职责：
// - 捕获 Store 传入的创建参数
// - 返回测试指定响应
@MainActor
private final class CapturingMerchantCreateRepository: MerchantRepository {
    var createResult: Result<MHBAPIResponse<MerchantManagedPet>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var receivedMerchantID: String?
    private(set) var receivedDraft: MerchantPetDraft?
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
        receivedMerchantID = merchantID
        receivedDraft = draft
        receivedUserID = currentUserID
        switch createResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
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
        throw .invalidResponse
    }
}
