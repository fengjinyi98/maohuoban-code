import XCTest
@testable import maohuoban

// AIAssistantMessageTimelinePresentationTests AI 消息时间线展示策略测试
// 核心职责：
// - 固化异常追踪主动追问标签选择规则
// - 防止同一 episode 第二轮追问误标旧助手消息
@MainActor
final class AIAssistantMessageTimelinePresentationTests: XCTestCase {
    func testAbnormalEpisodeContextShowsBadgeOnLatestCompletedAssistantMessage() {
        let firstAssistant = AIAssistantMessage(
            id: UUID(),
            role: .assistant,
            text: "早上记录了拉肚子，现在情况好转了吗？",
            isStreaming: false
        )
        let latestAssistant = AIAssistantMessage(
            id: UUID(),
            role: .assistant,
            text: "距离上次观察又过了 6 小时，现在便便和精神怎么样？",
            isStreaming: false
        )
        let presentation = AIAssistantMessageTimelinePresentation(
            messages: [
                firstAssistant,
                AIAssistantMessage(role: .user, text: "还是有点软便"),
                latestAssistant,
            ],
            hasAbnormalEpisodeContext: true
        )

        XCTAssertFalse(presentation.shouldShowProactiveFollowupBadge(for: firstAssistant))
        XCTAssertTrue(presentation.shouldShowProactiveFollowupBadge(for: latestAssistant))
    }

    func testDefaultContextDoesNotShowProactiveFollowupBadge() {
        let assistant = AIAssistantMessage(
            role: .assistant,
            text: "可以继续观察。",
            isStreaming: false
        )
        let presentation = AIAssistantMessageTimelinePresentation(
            messages: [assistant],
            hasAbnormalEpisodeContext: false
        )

        XCTAssertFalse(presentation.shouldShowProactiveFollowupBadge(for: assistant))
    }
}
