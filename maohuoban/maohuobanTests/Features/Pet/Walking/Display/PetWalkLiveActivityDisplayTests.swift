import XCTest
@testable import maohuoban

// PetWalkLiveActivityDisplayTests 遛弯实时事件展示测试
// 核心职责：
// - 固化灵动岛和实时事件的展示文案
// - 验证收起态轮播内容顺序和滚动方向
@MainActor
final class PetWalkLiveActivityDisplayTests: XCTestCase {
    func testContentStateUsesWalkCopyAndChineseCalorieUnit() {
        let state = PetWalkActivityAttributes.ContentState.make(
            petName: "糯米",
            phase: .tracking,
            metrics: PetWalkMetrics(distanceMeters: 2_327, elapsedSeconds: 1_455),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(state.petName, "糯米")
        XCTAssertNil(state.petAvatarURLString)
        XCTAssertEqual(state.statusText, "正在遛弯")
        XCTAssertEqual(state.distanceText, "2.33 公里")
        XCTAssertEqual(state.elapsedText, "24:15")
        XCTAssertEqual(state.caloriesText, "128 千卡")
    }

    func testContentStateKeepsPetAvatarURLForWidgetRendering() {
        let state = PetWalkActivityAttributes.ContentState.make(
            petName: "糯米",
            petAvatarURLString: "https://example.com/nuomi.jpg",
            phase: .tracking,
            metrics: PetWalkMetrics(distanceMeters: 2_327, elapsedSeconds: 1_455),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(state.petAvatarURLString, "https://example.com/nuomi.jpg")
    }

    func testCompactPetAvatarUsesContentStateAvatarURL() {
        let state = PetWalkActivityAttributes.ContentState.make(
            petName: "糯米",
            petAvatarURLString: "https://example.com/nuomi.jpg",
            phase: .tracking,
            metrics: PetWalkMetrics(distanceMeters: 2_327, elapsedSeconds: 1_455),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(state.compactPetAvatarURLString, "https://example.com/nuomi.jpg")
    }

    func testPausedContentStateKeepsMetricTextAndShowsPausedStatus() {
        let state = PetWalkActivityAttributes.ContentState.make(
            petName: "糯米",
            phase: .paused,
            metrics: PetWalkMetrics(distanceMeters: 640, elapsedSeconds: 301),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(state.statusText, "已暂停")
        XCTAssertEqual(state.distanceText, "0.64 公里")
        XCTAssertEqual(state.elapsedText, "05:01")
        XCTAssertEqual(state.caloriesText, "35 千卡")
    }

    func testCompactCollapsedItemsRotateFromTimeToStatusToDistance() {
        let state = PetWalkActivityAttributes.ContentState.make(
            petName: "糯米",
            phase: .tracking,
            metrics: PetWalkMetrics(distanceMeters: 2_340, elapsedSeconds: 1_455),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(
            state.compactRotationItems.map(\.text),
            ["24:15", "正在遛弯", "2.34 公里"]
        )
        XCTAssertEqual(state.compactRotationDirection, .up)
    }
}
