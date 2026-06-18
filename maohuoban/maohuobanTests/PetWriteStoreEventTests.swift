import XCTest
@testable import maohuoban

// PetWriteStoreEventTests 宠物事件写入 Store 测试
// 核心职责：
// - 验证记录事件状态流
// - 固化事件写入请求上下文传递行为
@MainActor
final class PetWriteStoreEventTests: XCTestCase {
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
}
