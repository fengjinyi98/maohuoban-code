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
                            id: "weight-1",
                            petID: "pet-1",
                            kind: .health,
                            subkind: "weight",
                            title: "体重记录",
                            summary: "4.35kg",
                            visibility: .private,
                            occurredAt: "2026-06-14T09:20:00Z",
                            recordRevision: 1,
                            source: .event,
                            eventPayload: nil
                        ),
                        PetTimelineEntry(
                            id: "quick-1",
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

        let recordContext = PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/media/avatar.png",
            petSex: .female
        )

        await store.load(
            petID: "pet-1",
            currentUserID: "user-1",
            recordContext: recordContext
        )

        XCTAssertEqual(repository.receivedTimelinePetID, "pet-1")
        XCTAssertEqual(repository.receivedTimelineUserID, "user-1")
        guard case .loaded(let records) = store.phase else {
            return XCTFail("expected loaded phase")
        }
        XCTAssertEqual(records.map(\.id), ["weight-1", "quick-1", "pet-1-homecoming"])
        XCTAssertEqual(records[0].yearText, "2026")
        XCTAssertEqual(records[0].monthText, "6月")
        XCTAssertEqual(records[0].dateText, "06/14")
        XCTAssertEqual(records[0].timeText, "17:20")
        XCTAssertEqual(records[0].title, "体重记录")
        XCTAssertEqual(records[0].subtitle, "4.35kg")
        XCTAssertEqual(records[0].kindText, "体重")
        XCTAssertEqual(records[0].systemImage, "scalemass.fill")
        XCTAssertEqual(records[0].route, .weight(recordID: "weight-1", context: recordContext))
        XCTAssertEqual(records[1].route, .quickFact(recordID: "quick-1", kind: .appetiteNormal, context: recordContext))
        XCTAssertEqual(records[2].yearText, "2024")
        XCTAssertEqual(records[2].monthText, "6月")
        XCTAssertEqual(records[2].dateText, "06/16")
        XCTAssertEqual(records[2].timeText, "08:00")
        XCTAssertEqual(records[2].title, "到家的第一天")
        XCTAssertEqual(records[2].subtitle, "糯米来到你身边")
        XCTAssertEqual(records[2].kindText, "关键时刻")
        XCTAssertEqual(records[2].systemImage, "house.fill")
        XCTAssertNil(records[2].route)
    }

    func testLoadWithoutPetIDFailsBeforeRepositoryCall() async {
        let repository = CapturingPetRepository()
        let store = PetRecordHistoryStore(repository: repository)
        let recordContext = PetRecordEntryContext(
            petID: nil,
            petName: nil,
            petAvatarURL: nil,
            petSex: .unknown
        )

        await store.load(
            petID: nil,
            currentUserID: "user-1",
            recordContext: recordContext
        )

        XCTAssertEqual(store.phase, .failed("请先选择宠物"))
        XCTAssertNil(repository.receivedTimelinePetID)
    }

    func testLoadSkipsSameContextAfterLoadedToPreserveListState() async {
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
                            id: "quick-1",
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
                        )
                    ]
                )
            )
        )
        let store = PetRecordHistoryStore(repository: repository)
        let recordContext = PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/media/avatar.png",
            petSex: .female
        )

        await store.load(
            petID: "pet-1",
            currentUserID: "user-1",
            recordContext: recordContext
        )
        let loadedPhase = store.phase

        await store.load(
            petID: "pet-1",
            currentUserID: "user-1",
            recordContext: recordContext
        )

        XCTAssertEqual(repository.loadTimelineCallCount, 1)
        XCTAssertEqual(store.phase, loadedPhase)
    }

    func testRemoveRecordDeletesLoadedRowWithoutReloadingTimeline() async {
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
                            id: "quick-1",
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
                            id: "feeding-1",
                            petID: "pet-1",
                            kind: .daily,
                            subkind: "feeding",
                            title: "喂食记录",
                            summary: "正常份量",
                            visibility: .private,
                            occurredAt: "2026-06-13T08:20:00Z",
                            recordRevision: 1,
                            source: .event,
                            eventPayload: nil
                        )
                    ]
                )
            )
        )
        let store = PetRecordHistoryStore(repository: repository)
        let recordContext = PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/media/avatar.png",
            petSex: .female
        )

        await store.load(
            petID: "pet-1",
            currentUserID: "user-1",
            recordContext: recordContext
        )

        store.removeRecord(id: "quick-1")

        guard case .loaded(let records) = store.phase else {
            return XCTFail("expected loaded phase")
        }
        XCTAssertEqual(records.map(\.id), ["feeding-1"])
        XCTAssertEqual(repository.loadTimelineCallCount, 1)
    }

    func testForceReloadAfterDeletionReplacesRowsFromBackendTimeline() async {
        let repository = CapturingPetRepository()
        repository.loadTimelineResults = [
            .success(
                MHBAPIResponse(
                    success: true,
                    code: "pet.timeline_loaded",
                    message: "宠物时间线已加载",
                    data: PetTimeline(
                        petID: "pet-1",
                        events: [
                            PetTimelineEntry(
                                id: "abnormal-1",
                                petID: "pet-1",
                                kind: .health,
                                subkind: "abnormal_symptom",
                                title: "异常记录",
                                summary: "精神变差",
                                visibility: .private,
                                occurredAt: "2026-06-13T08:20:00Z",
                                recordRevision: 1,
                                source: .event,
                                eventPayload: nil
                            ),
                            PetTimelineEntry(
                                id: "followup-1",
                                petID: "pet-1",
                                kind: .health,
                                subkind: "symptom_followup",
                                title: "追加观察",
                                summary: "精神一般",
                                visibility: .private,
                                occurredAt: "2026-06-13T09:20:00Z",
                                recordRevision: 1,
                                source: .event,
                                eventPayload: nil
                            )
                        ]
                    )
                )
            ),
            .success(
                MHBAPIResponse(
                    success: true,
                    code: "pet.timeline_loaded",
                    message: "宠物时间线已加载",
                    data: PetTimeline(
                        petID: "pet-1",
                        events: [
                            PetTimelineEntry(
                                id: "feeding-1",
                                petID: "pet-1",
                                kind: .daily,
                                subkind: "feeding",
                                title: "喂食记录",
                                summary: "正常份量",
                                visibility: .private,
                                occurredAt: "2026-06-13T10:20:00Z",
                                recordRevision: 1,
                                source: .event,
                                eventPayload: nil
                            )
                        ]
                    )
                )
            )
        ]
        let store = PetRecordHistoryStore(repository: repository)
        let recordContext = PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/media/avatar.png",
            petSex: .female
        )

        await store.load(
            petID: "pet-1",
            currentUserID: "user-1",
            recordContext: recordContext
        )
        await store.load(
            petID: "pet-1",
            currentUserID: "user-1",
            recordContext: recordContext,
            force: true
        )

        guard case .loaded(let records) = store.phase else {
            return XCTFail("expected loaded phase")
        }
        XCTAssertEqual(records.map(\.id), ["feeding-1"])
        XCTAssertEqual(repository.loadTimelineCallCount, 2)
    }
}
