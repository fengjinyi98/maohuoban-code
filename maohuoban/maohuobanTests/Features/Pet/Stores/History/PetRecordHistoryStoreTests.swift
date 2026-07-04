import XCTest
@testable import maohuoban

// PetRecordHistoryStoreTests 宠物记录历史 Store 测试
// 核心职责：
// - 验证记录列表从宠物时间线后端读取
// - 固化生命周期事实和真实事件进入同一个列表状态
@MainActor
final class PetRecordHistoryStoreTests: XCTestCase {
    func testLoadTimelineTransitionsToLoadedRecordsAndPassesContext() async {
        let repository = CapturingPetRepository()
        repository.loadTimelineResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.timeline_loaded",
                message: "宠物时间线已加载",
                data: PetTimeline(
                    petID: "pet-1",
                    events: [
                        PetTimelineEntry(
                            id: "event-1",
                            petID: "pet-1",
                            kind: .health,
                            subkind: "appetite_normal",
                            title: "食欲正常",
                            summary: "今天食欲正常",
                            visibility: .private,
                            occurredAt: "2026-06-13T09:20:00Z",
                            recordRevision: 1,
                            source: .event,
                            eventPayload: nil
                        ),
                        PetTimelineEntry(
                            id: "pet-1-homecoming",
                            petID: "pet-1",
                            kind: .daily,
                            subkind: "homecoming",
                            title: "到家的第一天",
                            summary: "糯米来到你身边",
                            visibility: .private,
                            occurredAt: "2024-06-16T00:00:00Z",
                            recordRevision: 1,
                            source: .lifecycle,
                            eventPayload: nil
                        )
                    ]
                )
            )
        )
        let store = PetRecordHistoryStore(repository: repository)

        await store.load(petID: "pet-1", currentUserID: "user-1")

        XCTAssertEqual(repository.receivedTimelinePetID, "pet-1")
        XCTAssertEqual(repository.receivedTimelineUserID, "user-1")
        guard case .loaded(let records) = store.phase else {
            return XCTFail("expected loaded phase")
        }
        XCTAssertEqual(records.map(\.id), ["event-1", "pet-1-homecoming"])
        XCTAssertEqual(records[0].yearText, "2026")
        XCTAssertEqual(records[0].monthText, "6月")
        XCTAssertEqual(records[0].dateText, "06/13")
        XCTAssertEqual(records[0].timeText, "17:20")
        XCTAssertEqual(records[0].title, "食欲正常")
        XCTAssertEqual(records[0].subtitle, "今天食欲正常")
        XCTAssertEqual(records[0].kindText, "快速记录")
        XCTAssertEqual(records[0].systemImage, "takeoutbag.and.cup.and.straw.fill")
        XCTAssertEqual(records[0].route, .quickFact(recordID: "event-1", kind: .appetiteNormal, context: nil))
        XCTAssertEqual(records[1].yearText, "2024")
        XCTAssertEqual(records[1].monthText, "6月")
        XCTAssertEqual(records[1].dateText, "06/16")
        XCTAssertEqual(records[1].timeText, "08:00")
        XCTAssertEqual(records[1].title, "到家的第一天")
        XCTAssertEqual(records[1].subtitle, "糯米来到你身边")
        XCTAssertEqual(records[1].kindText, "关键时刻")
        XCTAssertEqual(records[1].systemImage, "house.fill")
        XCTAssertNil(records[1].route)
    }

    func testLoadWithoutPetIDFailsBeforeRepositoryCall() async {
        let repository = CapturingPetRepository()
        let store = PetRecordHistoryStore(repository: repository)

        await store.load(petID: nil, currentUserID: "user-1")

        XCTAssertEqual(store.phase, .failed("请先选择宠物"))
        XCTAssertNil(repository.receivedTimelinePetID)
    }
}
