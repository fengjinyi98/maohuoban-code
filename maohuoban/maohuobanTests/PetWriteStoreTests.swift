import XCTest
@testable import maohuoban

// PetWriteStoreTests 宠物创建 Store 测试
// 核心职责：
// - 验证创建宠物状态流
// - 固化创建请求的当前用户上下文传递行为
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

    func testCreatePetWithUploadedMediaBindsAssetIDsInCreateRequest() async {
        let repository = CapturingPetRepository()
        repository.createPetResult = .success(Self.createPetResponse())
        let store = PetWriteStore(repository: repository)

        await store.createPetWithUploadedMedia(
            draft: PetProfileDraft(
                name: "糯米",
                species: .dog,
                breed: "",
                sex: .unknown,
                birthday: ""
            ),
            mediaBindings: PetUploadedMediaBindings(
                avatarAssetID: "avatar-asset-1",
                backgroundAssetID: "background-asset-1"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .createdPet("pet-1"))
        XCTAssertEqual(repository.callOrder, ["create"])
        XCTAssertEqual(repository.receivedCreateDraft?.avatarAssetID, "avatar-asset-1")
        XCTAssertEqual(repository.receivedCreateDraft?.backgroundAssetID, "background-asset-1")
    }
}
