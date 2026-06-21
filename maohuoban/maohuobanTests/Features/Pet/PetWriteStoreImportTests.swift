import XCTest
@testable import maohuoban

// PetWriteStoreImportTests 交易宠物导入 Store 测试
// 核心职责：
// - 验证交易宠物导入状态流
// - 验证交易来源方前置校验行为
@MainActor
final class PetWriteStoreImportTests: XCTestCase {
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
}
