import XCTest
@testable import maohuoban

// AIAssistantScrollStateTrackerTests 滚动状态追踪器单测
// 核心职责：
// - 锁定自动滚动模式切换规则
// - 确保用户拖动时暂停自动跟随，拖动结束在底部时恢复
final class AIAssistantScrollStateTrackerTests: XCTestCase {

    // MARK: - 用户拖动开始

    func testModeAfterUserDragBeganSwitchesToManual() {
        let mode = AIAssistantAutoScrollMode.followBottom
        let result = AIAssistantScrollStateTracker.modeAfterUserDragBegan(currentMode: mode)
        XCTAssertEqual(result, .manual)
    }

    // MARK: - 用户拖动结束

    func testModeAfterUserDragEndedAtBottomRestoresFollowBottom() {
        let mode = AIAssistantAutoScrollMode.manual
        let result = AIAssistantScrollStateTracker.modeAfterUserDragEnded(
            currentMode: mode,
            isScrolledToBottom: true
        )
        XCTAssertEqual(result, .followBottom)
    }

    func testModeAfterUserDragEndedNotBottomStaysManual() {
        let mode = AIAssistantAutoScrollMode.manual
        let result = AIAssistantScrollStateTracker.modeAfterUserDragEnded(
            currentMode: mode,
            isScrolledToBottom: false
        )
        XCTAssertEqual(result, .manual)
    }

    // MARK: - 是否应自动滚动

    func testShouldAutoScrollWhenFollowBottomAndNotPaused() {
        let result = AIAssistantScrollStateTracker.shouldAutoScroll(
            currentMode: .followBottom,
            isUserDragging: false,
            cooldownUntil: nil
        )
        XCTAssertTrue(result)
    }

    func testShouldNotAutoScrollWhenManual() {
        let result = AIAssistantScrollStateTracker.shouldAutoScroll(
            currentMode: .manual,
            isUserDragging: false,
            cooldownUntil: nil
        )
        XCTAssertFalse(result)
    }

    func testShouldNotAutoScrollWhenUserDragging() {
        let result = AIAssistantScrollStateTracker.shouldAutoScroll(
            currentMode: .followBottom,
            isUserDragging: true,
            cooldownUntil: nil
        )
        XCTAssertFalse(result)
    }

    func testShouldNotAutoScrollDuringCooldown() {
        let cooldown = Date().addingTimeInterval(0.2)
        let result = AIAssistantScrollStateTracker.shouldAutoScroll(
            currentMode: .followBottom,
            isUserDragging: false,
            cooldownUntil: cooldown
        )
        XCTAssertFalse(result)
    }

    // MARK: - 滚动到底部按钮显示

    func testShouldShowScrollToLatestButtonWhenNotAtBottom() {
        let result = AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: 5,
            isScrolledToBottom: false
        )
        XCTAssertTrue(result)
    }

    func testShouldNotShowScrollToLatestButtonWhenAtBottom() {
        let result = AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: 5,
            isScrolledToBottom: true
        )
        XCTAssertFalse(result)
    }

    func testShouldNotShowScrollToLatestButtonWhenNoMessages() {
        let result = AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: 0,
            isScrolledToBottom: false
        )
        XCTAssertFalse(result)
    }

    func testShouldNotAutoScrollToBottomWhenContentFitsViewport() {
        let result = AIAssistantScrollStateTracker.shouldAutoScrollToBottom(
            contentHeight: 480,
            viewportHeight: 640
        )
        XCTAssertFalse(result)
    }

    func testShouldAutoScrollToBottomWhenContentExceedsViewport() {
        let result = AIAssistantScrollStateTracker.shouldAutoScrollToBottom(
            contentHeight: 720,
            viewportHeight: 640
        )
        XCTAssertTrue(result)
    }
}
