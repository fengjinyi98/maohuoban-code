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
    private(set) var receivedCreateDraft: PetProfileDraft?
    private(set) var receivedCreateUserID: String?
    private(set) var receivedEventPetID: String?
    private(set) var receivedEventDraft: PetEventDraft?
    private(set) var receivedEventUserID: String?
    private(set) var receivedImportDraft: TradePetImportDraft?
    private(set) var receivedImportUserID: String?

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
