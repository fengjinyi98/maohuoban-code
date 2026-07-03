import XCTest
@testable import maohuoban

// PetWeightRecordStoreTests 体重记录 Store 测试
// 核心职责：
// - 固化体重记录列表、新增、编辑、删除的单一数据流
// - 约束空态文案与备注字段展示来源
@MainActor
final class PetWeightRecordStoreTests: XCTestCase {
    func testLoadRecordsReplacesLocalStateAndBuildsSummary() async {
        let repository = CapturingPetRepository()
        repository.listWeightRecordsResult = .success(Self.listResponse(items: [
            Self.record(id: "weight-2", grams: 4300, note: "饭后称重", occurredAt: "2026-07-04T02:00:00Z"),
            Self.record(id: "weight-1", grams: 4200, note: "晨间称重", occurredAt: "2026-07-03T01:00:00Z")
        ]))
        let store = PetWeightRecordStore(
            petID: "pet-1",
            currentUserID: "user-1",
            repository: repository
        )

        await store.load()

        XCTAssertEqual(store.records.map(\.id), ["weight-2", "weight-1"])
        XCTAssertEqual(store.currentWeightText, "4.30")
        XCTAssertEqual(store.weightChangeText, "+ 0.10 kg")
        XCTAssertEqual(store.records.first?.note, "饭后称重")
        XCTAssertEqual(repository.receivedListWeightPetID, "pet-1")
    }

    func testEmptyStateCopyGuidesFirstRecordCreation() async {
        let repository = CapturingPetRepository()
        repository.listWeightRecordsResult = .success(Self.listResponse(items: []))
        let store = PetWeightRecordStore(
            petID: "pet-1",
            currentUserID: "user-1",
            repository: repository
        )

        await store.load()

        XCTAssertTrue(store.isEmpty)
        XCTAssertEqual(store.emptyStateTitle, "还没有体重记录")
        XCTAssertEqual(store.emptyStateMessage, "记录第一次称重后，就能看到毛伙伴的体重变化。")
        XCTAssertEqual(store.emptyStateButtonTitle, "添加体重记录")
    }

    func testCreateAndUpdateRecordsUseRepositoryAndRefreshLocalItems() async {
        let repository = CapturingPetRepository()
        repository.createWeightRecordResult = .success(Self.singleResponse(Self.record(
            id: "weight-1",
            grams: 4200,
            note: "饭前称重",
            occurredAt: "2026-07-04T01:00:00Z"
        )))
        repository.updateWeightRecordResult = .success(Self.singleResponse(Self.record(
            id: "weight-1",
            grams: 4300,
            note: "更新备注",
            occurredAt: "2026-07-04T02:00:00Z"
        )))
        let store = PetWeightRecordStore(
            petID: "pet-1",
            currentUserID: "user-1",
            repository: repository
        )

        let didCreate = await store.create(
            draft: PetWeightRecordDraft(
                weightGrams: 4200,
                note: "饭前称重",
                occurredAt: "2026-07-04T01:00:00Z"
            )
        )
        let didUpdate = await store.update(
            recordID: "weight-1",
            draft: PetWeightRecordDraft(
                weightGrams: 4300,
                note: "更新备注",
                occurredAt: "2026-07-04T02:00:00Z"
            )
        )

        XCTAssertTrue(didCreate)
        XCTAssertTrue(didUpdate)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.weightGrams, 4300)
        XCTAssertEqual(store.records.first?.note, "更新备注")
        XCTAssertEqual(repository.receivedCreateWeightDraft?.note, "饭前称重")
        XCTAssertEqual(repository.receivedUpdateWeightRecordID, "weight-1")
    }

    func testDeleteRecordRemovesLocalItem() async {
        let repository = CapturingPetRepository()
        repository.deleteWeightRecordResult = .success(MHBAPIResponse(
            success: true,
            code: "pet.weight_record_deleted",
            message: "体重记录已删除",
            data: DeletedPetWeightRecord(id: "weight-1", deleted: true)
        ))
        let store = PetWeightRecordStore(
            petID: "pet-1",
            currentUserID: "user-1",
            repository: repository,
            records: [
                Self.record(id: "weight-1", grams: 4200, note: "晨间称重", occurredAt: "2026-07-04T01:00:00Z"),
                Self.record(id: "weight-2", grams: 4300, note: "饭后称重", occurredAt: "2026-07-05T01:00:00Z")
            ]
        )

        let didDelete = await store.delete(recordID: "weight-1")

        XCTAssertTrue(didDelete)
        XCTAssertEqual(store.records.map(\.id), ["weight-2"])
        XCTAssertEqual(repository.receivedDeleteWeightRecordID, "weight-1")
    }

    private static func listResponse(items: [PetWeightRecord]) -> MHBAPIResponse<PetWeightRecordList> {
        MHBAPIResponse(
            success: true,
            code: "pet.weight_records_loaded",
            message: "体重记录已加载",
            data: PetWeightRecordList(items: items)
        )
    }

    private static func singleResponse(_ record: PetWeightRecord) -> MHBAPIResponse<PetWeightRecord> {
        MHBAPIResponse(
            success: true,
            code: "pet.weight_record_saved",
            message: "体重记录已保存",
            data: record
        )
    }

    private static func record(
        id: String,
        grams: Int,
        note: String,
        occurredAt: String
    ) -> PetWeightRecord {
        PetWeightRecord(
            id: id,
            petID: "pet-1",
            weightGrams: grams,
            note: note,
            source: .manual,
            occurredAt: occurredAt,
            recordRevision: 1,
            createdAt: occurredAt,
            updatedAt: occurredAt
        )
    }
}
