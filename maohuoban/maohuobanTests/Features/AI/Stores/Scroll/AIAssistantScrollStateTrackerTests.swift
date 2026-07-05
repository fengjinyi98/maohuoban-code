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
            isScrolledToBottom: false,
            hasUserScrolled: true,
            contentHeight: 1200,
            viewportHeight: 640
        )
        XCTAssertTrue(result)
    }

    func testShouldNotShowScrollToLatestButtonWhenAtBottom() {
        let result = AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: 5,
            isScrolledToBottom: true,
            hasUserScrolled: true,
            contentHeight: 1200,
            viewportHeight: 640
        )
        XCTAssertFalse(result)
    }

    func testShouldNotShowScrollToLatestButtonWhenNoMessages() {
        let result = AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: 0,
            isScrolledToBottom: false,
            hasUserScrolled: true,
            contentHeight: 1200,
            viewportHeight: 640
        )
        XCTAssertFalse(result)
    }

    func testShouldNotShowScrollToLatestButtonBeforeUserScrolls() {
        let result = AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: 5,
            isScrolledToBottom: false,
            hasUserScrolled: false,
            contentHeight: 1200,
            viewportHeight: 640
        )
        XCTAssertFalse(result)
    }

    func testShouldNotShowScrollToLatestButtonWhenContentCannotScroll() {
        let result = AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: 5,
            isScrolledToBottom: false,
            hasUserScrolled: true,
            contentHeight: 520,
            viewportHeight: 640
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

    func testIsScrolledToBottomWhenDistanceWithinThreshold() {
        let result = AIAssistantScrollStateTracker.isScrolledToBottom(
            contentOffsetY: 772,
            visibleMaxY: 1172,
            contentHeight: 1200,
            viewportHeight: 400,
            threshold: 28
        )

        XCTAssertTrue(result)
    }

    func testIsNotScrolledToBottomWhenDistanceExceedsThreshold() {
        let result = AIAssistantScrollStateTracker.isScrolledToBottom(
            contentOffsetY: 720,
            visibleMaxY: 1120,
            contentHeight: 1200,
            viewportHeight: 400,
            threshold: 28
        )

        XCTAssertFalse(result)
    }

    func testShouldNotShowScrollToLatestButtonWhenContentOnlySlightlyExceedsViewport() {
        let result = AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: 5,
            isScrolledToBottom: false,
            hasUserScrolled: true,
            contentHeight: 642,
            viewportHeight: 640
        )

        XCTAssertFalse(result)
    }

    func testShouldNotMarkUserScrolledWhenContentGrowthMovesBottomAway() {
        let result = AIAssistantScrollStateTracker.shouldMarkUserScrolled(
            isScrolledToBottom: false,
            hasUserScrollIntent: false
        )

        XCTAssertFalse(result)
    }

    func testShouldMarkUserScrolledWhenUserDragMovesAwayFromBottom() {
        let result = AIAssistantScrollStateTracker.shouldMarkUserScrolled(
            isScrolledToBottom: false,
            hasUserScrollIntent: true
        )

        XCTAssertTrue(result)
    }

    func testShouldFollowBottomWhenContentGrowsWithoutUserScroll() {
        let result = AIAssistantScrollStateTracker.shouldFollowBottomAfterContentGrowth(
            previousIsScrolledToBottom: true,
            hasUserScrolled: false,
            hasUserScrollIntent: false,
            previousContentHeight: 222,
            nextContentHeight: 1123,
            viewportHeight: 613
        )

        XCTAssertTrue(result)
    }

    func testShouldNotFollowBottomWhenUserHasScrolledAway() {
        let result = AIAssistantScrollStateTracker.shouldFollowBottomAfterContentGrowth(
            previousIsScrolledToBottom: false,
            hasUserScrolled: true,
            hasUserScrollIntent: false,
            previousContentHeight: 1123,
            nextContentHeight: 1157,
            viewportHeight: 613
        )

        XCTAssertFalse(result)
    }

    func testShouldNotFollowBottomWhenUserIsActivelyScrolling() {
        let result = AIAssistantScrollStateTracker.shouldFollowBottomAfterContentGrowth(
            previousIsScrolledToBottom: true,
            hasUserScrolled: false,
            hasUserScrollIntent: true,
            previousContentHeight: 1017,
            nextContentHeight: 1285,
            viewportHeight: 613
        )

        XCTAssertFalse(result)
    }

    func testShortContentIsAlwaysAtBottom() {
        let result = AIAssistantScrollStateTracker.isScrolledToBottom(
            contentOffsetY: 0,
            visibleMaxY: 360,
            contentHeight: 360,
            viewportHeight: 640,
            threshold: 28
        )

        XCTAssertTrue(result)
    }

    func testCanScrollIgnoresTinyBoundaryDelta() {
        let result = AIAssistantScrollStateTracker.canScroll(
            contentHeight: 642,
            viewportHeight: 640,
            threshold: 28
        )

        XCTAssertFalse(result)
    }

    func testBottomDetectionUsesVisibleRectMaxY() {
        let result = AIAssistantScrollStateTracker.isScrolledToBottom(
            contentOffsetY: 318,
            visibleMaxY: 1318,
            contentHeight: 1326,
            viewportHeight: 569,
            threshold: 28
        )

        XCTAssertTrue(result)
    }
}
