import XCTest
@testable import maohuoban

// PetWalkLiveActivitySyncTests 遛弯实时事件同步测试
// 核心职责：
// - 固化遛弯状态到 ActivityKit 操作的映射
// - 防止暂停、继续和结束时产生错误的实时事件生命周期
@MainActor
final class PetWalkLiveActivitySyncTests: XCTestCase {
    func testTrackingStartsThenUpdatesExistingLiveActivity() {
        var planner = PetWalkLiveActivitySyncPlanner()
        let snapshot = makeSnapshot(phase: .tracking)

        XCTAssertEqual(planner.nextCommand(for: snapshot)?.kind, .start)
        XCTAssertEqual(planner.nextCommand(for: snapshot)?.kind, .update)
    }

    func testPausedUpdatesExistingLiveActivity() {
        var planner = PetWalkLiveActivitySyncPlanner()

        _ = planner.nextCommand(for: makeSnapshot(phase: .tracking))

        let command = planner.nextCommand(for: makeSnapshot(phase: .paused))

        XCTAssertEqual(command?.kind, .update)
        XCTAssertEqual(command?.state.statusText, "已暂停")
        XCTAssertEqual(command?.state.petAvatarURLString, "https://example.com/nuomi.jpg")
    }

    func testFinishedEndsExistingLiveActivityOnce() {
        var planner = PetWalkLiveActivitySyncPlanner()

        _ = planner.nextCommand(for: makeSnapshot(phase: .tracking))

        XCTAssertEqual(planner.nextCommand(for: makeSnapshot(phase: .finished))?.kind, .end)
        XCTAssertNil(planner.nextCommand(for: makeSnapshot(phase: .finished)))
    }

    func testReadyDoesNotStartLiveActivity() {
        var planner = PetWalkLiveActivitySyncPlanner()

        XCTAssertNil(planner.nextCommand(for: makeSnapshot(phase: .ready)))
    }

    private func makeSnapshot(phase: PetWalkSessionPhase) -> PetWalkLiveActivitySnapshot {
        PetWalkLiveActivitySnapshot(
            sessionID: "walk-1",
            petName: "糯米",
            petAvatarURLString: "https://example.com/nuomi.jpg",
            phase: phase,
            metrics: PetWalkMetrics(distanceMeters: 1_000, elapsedSeconds: 600),
            updatedAt: Date(timeIntervalSince1970: 10)
        )
    }
}
