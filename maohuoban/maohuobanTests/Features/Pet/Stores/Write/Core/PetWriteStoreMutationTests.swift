import XCTest
@testable import maohuoban

// PetWriteStoreMutationTests 宠物档案变更 Store 测试
// 核心职责：
// - 验证宠物档案更新状态流
// - 验证宠物档案删除状态流
@MainActor
final class PetWriteStoreMutationTests: XCTestCase {
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
                    note: "喜欢晒太阳",
                    nameEditPolicy: PetNameEditPolicy(
                        maxCount: 5,
                        usedCount: 2,
                        remainingCount: 3,
                        windowDays: 30,
                        windowEndsAt: "2026-07-17T00:00:00Z",
                        displayText: "7月17日前还可以修改 3 次名字。"
                    )
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
        XCTAssertEqual(store.latestPetProfile?.nameEditPolicy?.remainingCount, 3)
        XCTAssertEqual(store.latestPetProfile?.nameEditPolicy?.displayText, "7月17日前还可以修改 3 次名字。")
        XCTAssertEqual(repository.receivedUpdatePetID, "pet-1")
        XCTAssertEqual(repository.receivedUpdateUserID, "user-1")
        XCTAssertEqual(repository.receivedUpdateDraft?.weightGrams, 4800)
    }

    func testUpdatePetBlocksTerminalLifeStatusWithoutCallingRepository() async {
        let repository = CapturingPetRepository()
        let store = PetWriteStore(repository: repository)

        await store.updatePet(
            petID: "pet-1",
            draft: PetProfileUpdateDraft(
                name: "糯米",
                species: .dog,
                breed: "",
                sex: .female,
                birthday: "2024-04-01",
                microchipNumber: "",
                arrivalDate: "2024-06-16",
                weightGrams: 4800,
                neuterStatus: .neutered,
                personalityTags: ["亲人"],
                note: "喜欢晒太阳"
            ),
            currentUserID: "user-1",
            lifeStatus: "deceased"
        )

        XCTAssertEqual(store.phase, .failed("当前生命状态不支持写入"))
        XCTAssertNil(repository.receivedUpdatePetID)
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
}
