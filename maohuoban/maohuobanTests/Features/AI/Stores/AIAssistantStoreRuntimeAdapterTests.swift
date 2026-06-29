import XCTest
@testable import maohuoban

// AIAssistantStoreRuntimeAdapterTests AI runtime adapter 状态测试
// 核心职责：
// - 验证 Store 消费后端稳定 SSE 工具态和确认态
// - 验证 Provider error 后恢复发送入口
@MainActor
final class AIAssistantStoreRuntimeAdapterTests: XCTestCase {

    func testErrorEventRestoresDraftSendAvailability() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: RuntimeAdapterTestRepository(streamEvents: Self.errorEvents())
        )
        store.draftText = "测试"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)
        store.draftText = "继续提问"

        XCTAssertFalse(store.isStreaming)
        XCTAssertTrue(store.canSendDraft)
    }

    func testConfirmationEventExposesAssistantStatus() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: RuntimeAdapterTestRepository(streamEvents: Self.confirmationEvents())
        )
        store.draftText = "帮我确认换粮"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.pendingConfirmationTask?.questionText, "是否确认把毛球的主粮改为鸡肉配方？")
        XCTAssertFalse(store.isStreaming)
    }

    func testAgentActivityUsesBackendTextAndClearsWhenCompleted() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(
            .agentActivity(displayText: "正在查看毛球近期饮食", status: "started")
        )
        XCTAssertEqual(store.activeAgentActivityText, "正在查看毛球近期饮食")
        XCTAssertEqual(store.messages.last?.text, "")

        store.handleStreamEvent(
            .agentActivity(displayText: "正在查看毛球近期饮食", status: "completed")
        )
        XCTAssertNil(store.activeAgentActivityText)
        XCTAssertEqual(store.messages.last?.text, "")
    }

    func testAgentActivityClearsWhenAnswerDeltaArrives() async {
        let store = Self.makeStoreWithStreamingPlaceholder()

        store.handleStreamEvent(
            .agentActivity(displayText: "正在查看毛球近期饮食", status: "started")
        )
        XCTAssertEqual(store.activeAgentActivityText, "正在查看毛球近期饮食")

        store.handleStreamEvent(.delta(text: "先观察精神状态"))

        XCTAssertNil(store.activeAgentActivityText)
        XCTAssertEqual(store.messages.last?.text, "先观察精神状态")
    }

    private static func makeStoreWithStreamingPlaceholder() -> AIAssistantStore {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: RuntimeAdapterTestRepository(streamEvents: [])
        )
        store.ensureStreamingPlaceholderExists()
        return store
    }

    private static func errorEvents() -> [AIStreamEventDTO] {
        [
            .messageStarted(chatSessionID: UUID(), messageID: UUID(), title: "新对话"),
            .error(
                code: "ai.provider_not_configured",
                message: "AI 服务未配置",
                retryable: false,
                safeFallbackText: "AI 服务暂时不可用，请稍后重试。"
            ),
        ]
    }

    private static func confirmationEvents() -> [AIStreamEventDTO] {
        [
            .messageStarted(chatSessionID: UUID(), messageID: UUID(), title: "换粮确认"),
            .agentActivity(displayText: "正在查看毛球待确认喂食记录", status: "completed"),
            .confirmationTask(
                taskID: UUID(),
                questionText: "是否确认把毛球的主粮改为鸡肉配方？"
            ),
            .messageCompleted(
                messageID: UUID(),
                finalText: "需要你确认后再记录。",
                referenceChips: []
            ),
        ]
    }
}
