import XCTest
@testable import maohuoban

// PetAbnormalDetailStoreTests 异常详情 Store 测试
// 核心职责：
// - 验证异常详情删除事件的单一状态流
// - 固化删除时的事件 ID 和用户上下文传递
@MainActor
final class PetAbnormalDetailStoreTests: XCTestCase {
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
