import XCTest
@testable import maohuoban

// AIAssistantStoreStreamEventTests Store 流式事件消费测试
// 核心职责：
// - 验证 Store 正确消费 Repository 返回的流式事件
// - 验证 error 事件关闭流式状态并展示安全回退文案
// - 验证网络错误关闭流式状态
@MainActor
final class AIAssistantStoreStreamEventTests: XCTestCase {

    func testFullStreamFlowAccumulatesText() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.fullFlowEvents())
        )
        store.draftText = "毛球拉肚子了"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        // 用户消息 + 助手消息
        XCTAssertEqual(store.messages.count, 2)
        let assistant = store.messages[1]
        XCTAssertEqual(assistant.role, .assistant)
        XCTAssertFalse(assistant.isStreaming)
        XCTAssertEqual(assistant.text, "需要观察精神状态和食欲")
        XCTAssertEqual(assistant.referenceChips, ["健康分级", "红旗症状"])
    }

    func testErrorEventClosesStreamingAndShowsFallback() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.errorEvents())
        )
        store.draftText = "测试"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(store.isStreaming)
        guard let lastMessage = store.messages.last else {
            XCTFail("没有消息")
            return
        }
        XCTAssertFalse(lastMessage.isStreaming)
        XCTAssertEqual(lastMessage.text, "暂时无法获取回答，请稍后重试。")
    }

    func testProposedActionSetsPendingAction() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.streamWithAction())
        )
        store.draftText = "疫苗"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(store.pendingAction)
        XCTAssertEqual(store.pendingAction?.confirmTitle, "确认换粮")
    }

    func testMessageStartedSetsConversationTitle() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.titleEvents())
        )
        store.draftText = "问题"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.navigationTitle, "疫苗咨询")
    }

    func testConfirmPendingActionAppendsMessages() async {
        let repository = MockAIAssistantRepository(streamEvents: Self.streamWithAction())
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: repository
        )
        store.draftText = "疫苗"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        let countBefore = store.messages.count
        guard let actionID = store.pendingAction?.id else {
            XCTFail("没有待确认动作")
            return
        }
        store.confirmPendingAction()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.messages.count, countBefore + 2)
        XCTAssertEqual(store.messages[countBefore].role, .user)
        XCTAssertEqual(store.messages[countBefore + 1].role, .assistant)
        XCTAssertEqual(store.messages[countBefore + 1].text, "已完成这次确认。")
        XCTAssertEqual(repository.confirmedActionIDs, [actionID])
        XCTAssertNil(store.pendingAction)
    }

    func testCancelPendingActionClearsAndAppendsMessage() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.streamWithAction())
        )
        store.draftText = "疫苗"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        let countBefore = store.messages.count
        store.cancelPendingAction()

        XCTAssertNil(store.pendingAction)
        XCTAssertEqual(store.messages.count, countBefore + 1)
        XCTAssertEqual(store.messages[countBefore].role, .assistant)
    }

    func testStartNewConversationClearsAllState() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.fullFlowEvents())
        )
        store.draftText = "测试"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(store.messages.isEmpty)

        store.startNewConversation()

        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertNil(store.selectedConversationHistoryID)
        XCTAssertNil(store.currentConversationTitle)
        XCTAssertTrue(store.draftText.isEmpty)
        XCTAssertNil(store.pendingAction)
    }

    // MARK: - Helpers

    private static func fullFlowEvents() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "腹泻观察"),
            .delta(text: "需要观察"),
            .delta(text: "精神状态和食欲"),
            .messageCompleted(
                messageID: messageID,
                finalText: "需要观察精神状态和食欲",
                referenceChips: ["健康分级", "红旗症状"]
            ),
        ]
    }

    private static func errorEvents() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "新对话"),
            .error(
                code: "ai.provider_not_configured",
                message: "AI 服务未配置",
                retryable: false,
                safeFallbackText: "暂时无法获取回答，请稍后重试。"
            ),
        ]
    }

    private static func streamWithAction() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        let actionID = UUID()
        let petID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "疫苗咨询"),
            .delta(text: "建议确认换粮"),
            .messageCompleted(
                messageID: messageID,
                finalText: "建议确认换粮",
                referenceChips: ["饮食记录"]
            ),
            .proposedAction(action: AIProposedActionDTO(
                id: actionID,
                actionKind: "diet_change_confirmation",
                targetPetID: petID,
                confirmText: "确认换粮",
                riskLevel: "low",
                payload: AIProposedActionPayloadDTO(
                    foodItemID: UUID(),
                    confirmedFactKind: "diet_change",
                    sourceQuestion: "是否确认换粮？",
                    deriveDietChange: true,
                    deriveFeedingCorrection: false
                )
            )),
        ]
    }

    private static func titleEvents() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "疫苗咨询"),
            .messageCompleted(
                messageID: messageID,
                finalText: "ok",
                referenceChips: []
            ),
        ]
    }
}
