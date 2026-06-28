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

    func testToolAndConfirmationEventsExposeAssistantStatus() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: RuntimeAdapterTestRepository(streamEvents: Self.toolAndConfirmationEvents())
        )
        store.draftText = "帮我确认换粮"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.activeToolStatus?.toolName, "load_pet_diet_confirmation_candidates")
        XCTAssertEqual(store.activeToolStatus?.status, "allowed")
        XCTAssertEqual(store.activeToolStatus?.citationCount, 1)
        XCTAssertEqual(store.pendingConfirmationTask?.questionText, "是否确认把毛球的主粮改为鸡肉配方？")
        XCTAssertFalse(store.isStreaming)
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

    private static func toolAndConfirmationEvents() -> [AIStreamEventDTO] {
        [
            .messageStarted(chatSessionID: UUID(), messageID: UUID(), title: "换粮确认"),
            .toolCall(
                toolName: "load_pet_diet_confirmation_candidates",
                status: "allowed",
                citationCount: 1
            ),
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
