import XCTest
@testable import maohuoban

// PetAbnormalDetailStoreTests 异常详情 Store 测试
// 核心职责：
// - 验证异常详情删除事件的单一状态流
// - 固化删除时的事件 ID 和用户上下文传递
@MainActor
final class PetAbnormalDetailStoreTests: XCTestCase {
    func testLoadProjectsEpisodeProgressRecordsFromTimeline() async {
        let repository = CapturingPetRepository()
        repository.loadEventDetailResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.event_loaded",
                message: "事件详情已加载",
                data: PetEventDetail(
                    id: "event-1",
                    petID: "pet-1",
                    litterID: nil,
                    kind: .health,
                    subkind: "abnormal_symptom",
                    title: "异常记录",
                    summary: "异常：精神差",
                    visibility: .private,
                    occurredAt: "2026-07-05T10:00:00Z",
                    recordRevision: 1,
                    eventPayload: PetEventDetailPayload(episodeID: "episode-1")
                )
            )
        )
        repository.loadTimelineResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.timeline_loaded",
                message: "时间线已加载",
                data: PetTimeline(
                    petID: "pet-1",
                    events: [
                        PetTimelineEntry(
                            id: "followup-1",
                            petID: "pet-1",
                            kind: .health,
                            subkind: "symptom_followup",
                            title: "追加观察",
                            summary: "精神一般",
                            visibility: .private,
                            occurredAt: "2026-07-05T12:00:00Z",
                            recordRevision: 1,
                            source: .event,
                            eventPayload: PetEventDetailPayload(
                                note: "精神一般",
                                episodeID: "episode-1"
                            )
                        ),
                        PetTimelineEntry(
                            id: "other-1",
                            petID: "pet-1",
                            kind: .health,
                            subkind: "symptom_followup",
                            title: "其他观察",
                            summary: "不应展示",
                            visibility: .private,
                            occurredAt: "2026-07-05T13:00:00Z",
                            recordRevision: 1,
                            source: .event,
                            eventPayload: PetEventDetailPayload(episodeID: "episode-other")
                        )
                    ]
                )
            )
        )
        let store = PetAbnormalDetailStore(repository: repository)

        await store.load(eventID: "event-1", currentUserID: "user-1")

        XCTAssertEqual(repository.receivedLoadEventDetailID, "event-1")
        XCTAssertEqual(repository.receivedTimelinePetID, "pet-1")
        XCTAssertEqual(store.progressRecords.map(\.id), ["event-1", "followup-1"])
        XCTAssertEqual(store.progressRecords.count, 2)
        guard store.progressRecords.count == 2 else { return }
        let sourceRecord = store.progressRecords[0]
        let followupRecord = store.progressRecords[1]
        XCTAssertEqual(sourceRecord.kind, .abnormal)
        XCTAssertTrue(sourceRecord.isCurrentRecord)
        XCTAssertEqual(
            sourceRecord.timeText,
            MHBUTCDateDisplayFormatter.localShortText(fromUTCString: "2026-07-05T10:00:00Z")
        )
        XCTAssertEqual(
            followupRecord.timeText,
            MHBUTCDateDisplayFormatter.localShortText(fromUTCString: "2026-07-05T12:00:00Z")
        )
        XCTAssertNotEqual(sourceRecord.timeText, "2026-07-05T10:00:00Z")
        XCTAssertNotEqual(followupRecord.timeText, "2026-07-05T12:00:00Z")
        XCTAssertEqual(followupRecord.kind, .observation)
        XCTAssertEqual(followupRecord.subtitle, "精神一般")
    }

    func testAddObservationIncludesAttachmentAssetIDs() async {
        let repository = CapturingPetRepository()
        repository.createEventResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.event_created",
                message: "宠物事件已创建",
                data: PetEventSummary(
                    id: "followup-1",
                    petID: "pet-1",
                    kind: .health,
                    subkind: "symptom_followup",
                    title: "追加观察",
                    summary: "精神一般",
                    visibility: .private,
                    occurredAt: "2026-07-05T12:00:00Z",
                    recordRevision: 1
                )
            )
        )
        let store = PetAbnormalDetailStore(repository: repository)

        await store.addObservation(
            petID: "pet-1",
            note: "精神一般",
            currentUserID: "user-1",
            lifeStatus: nil,
            attachmentAssetIDs: ["asset-1", "asset-2"]
        )

        XCTAssertEqual(repository.receivedEventPetID, "pet-1")
        XCTAssertEqual(repository.receivedEventUserID, "user-1")
        XCTAssertEqual(repository.receivedEventDraft?.subkind, "symptom_followup")
        XCTAssertEqual(
            repository.receivedEventDraft?.eventPayload["attachment_asset_ids"],
            .stringArray(["asset-1", "asset-2"])
        )
    }

    func testDeleteTransitionsToDeletedAndPassesContext() async {
        let repository = CapturingPetRepository()
        repository.deleteEventResult = .success(
            MHBAPIResponse(
                success: true,
                code: "pet.event_deleted",
                message: "宠物事件已删除",
                data: DeletedPetEvent(id: "event-1", deleted: true)
            )
        )
        let store = PetAbnormalDetailStore(repository: repository)

        let didDelete = await store.delete(eventID: "event-1", currentUserID: "user-1")

        XCTAssertTrue(didDelete)
        XCTAssertEqual(store.phase, .deleted("event-1"))
        XCTAssertEqual(repository.receivedDeleteEventID, "event-1")
        XCTAssertEqual(repository.receivedDeleteEventUserID, "user-1")
    }
}
