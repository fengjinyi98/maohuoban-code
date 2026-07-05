import XCTest
@testable import maohuoban

// AIAssistantStoreStreamEventTests Store 流式事件消费测试
// 核心职责：
// - 验证 Store 正确消费 Repository 返回的流式事件
// - 验证 error 事件关闭流式状态并展示后端安全文案
// - 验证异常流不会生成前端 AI 回复兜底
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

    func testSubmitDraftShowsStreamingPlaceholderImmediately() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: PendingAIAssistantRepository()
        )
        store.draftText = "我的宠物下一次疫苗是什么时候"

        store.submitDraft()

        XCTAssertEqual(store.messages.count, 2)
        XCTAssertEqual(store.messages[0].role, .user)
        XCTAssertEqual(store.messages[1].role, .assistant)
        XCTAssertTrue(store.messages[1].isStreaming)
        XCTAssertTrue(store.messages[1].text.isEmpty)
        XCTAssertTrue(store.isStreaming)
    }

    func testErrorEventClosesStreamingAndShowsBackendSafeText() async {
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
        XCTAssertEqual(lastMessage.text, "AI 服务暂时不可用，请稍后重试。")
    }

    func testErrorEventWithoutSafeTextDoesNotAppendFrontendFallback() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.errorEventsWithoutSafeText())
        )
        store.draftText = "测试"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(store.isStreaming)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].role, .user)
    }

    func testMessageCompletedWithoutStartedShowsBackendFinalText() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.backendCompletionOnlyEvents())
        )
        store.draftText = "测试"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.messages.count, 2)
        guard store.messages.count == 2 else { return }
        XCTAssertEqual(store.messages[1].role, .assistant)
        XCTAssertFalse(store.messages[1].isStreaming)
        XCTAssertEqual(store.messages[1].text, "我现在只能处理宠物照护、宠物记录和毛伙伴 App 相关问题。")
    }

    func testStreamFailureBeforeMessageStartedAppendsFallbackReply() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: FailingAIAssistantRepository()
        )
        store.draftText = "毛球为什么不回复"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.messages.count, 2)
        guard store.messages.count == 2 else { return }
        XCTAssertEqual(store.messages[0].role, .user)
        XCTAssertEqual(store.messages[1].role, .assistant)
        XCTAssertFalse(store.messages[1].isStreaming)
        XCTAssertEqual(store.messages[1].text, "网络连接失败，请检查网络后重试。")
    }

    func testEmptyStreamDoesNotAppendFrontendFallbackReply() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: [])
        )
        store.draftText = "毛球为什么不回复"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(store.isStreaming)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].role, .user)
    }

    func testStartedStreamWithoutCompletedTextRemovesEmptyPlaceholder() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.startedOnlyEvents())
        )
        store.draftText = "毛球为什么不回复"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(store.isStreaming)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].role, .user)
    }

    func testLoopEndDoesNotDiscardReplyAfterTerminalAssistantEvent() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.messages = [
            AIAssistantMessage(role: .user, text: "继续"),
            AIAssistantMessage(role: .assistant, text: "这是已经完成的回复", isStreaming: false),
        ]

        store.finishStreamIfAssistantReplyMissing(after: 1, didReceiveAssistantReply: true)

        XCTAssertEqual(store.messages.count, 2)
        XCTAssertEqual(store.messages[1].role, .assistant)
        XCTAssertFalse(store.messages[1].isStreaming)
        XCTAssertEqual(store.messages[1].text, "这是已经完成的回复")
    }

    func testLoopEndUsesCompletionSequenceWhenLocalTerminalFlagIsLost() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        let completionSequenceBeforeStream = store.assistantReplyCompletionSequence
        store.messages = [
            AIAssistantMessage(role: .user, text: "继续"),
        ]
        store.ensureStreamingPlaceholderExists()
        store.handleStreamEvent(.messageCompleted(
            messageID: UUID(),
            finalText: "这是第二轮已经完成的回复",
            referenceChips: [],
            references: []
        ))

        store.finishStreamIfAssistantReplyMissing(
            after: 1,
            didReceiveAssistantReply: store.assistantReplyCompletionSequence > completionSequenceBeforeStream
        )

        XCTAssertEqual(store.messages.count, 2)
        XCTAssertEqual(store.messages[1].role, .assistant)
        XCTAssertFalse(store.messages[1].isStreaming)
        XCTAssertEqual(store.messages[1].text, "这是第二轮已经完成的回复")
    }

    func testMessageCompletedAppliesContentBlocksToAssistantMessage() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        let messageID = UUID()
        let blocks: [AIAssistantContentBlock] = [
            .sectionHeading(AIAssistantSectionHeadingBlock(id: "heading-1", text: "这是糯米的宠物信息")),
            .petProfileCardSkeleton(AIAssistantPetProfileSkeletonBlock(id: "loading-1", title: "正在整理宠物档案")),
        ]
        store.messages = [
            AIAssistantMessage(role: .user, text: "看看我的宠物"),
        ]
        store.ensureStreamingPlaceholderExists()

        store.handleStreamEvent(.messageCompleted(
            messageID: messageID,
            finalText: "这是糯米的宠物信息",
            referenceChips: [],
            references: [],
            contentBlocks: blocks
        ))

        XCTAssertEqual(store.messages.count, 2)
        let assistant = store.messages[1]
        XCTAssertFalse(assistant.isStreaming)
        XCTAssertEqual(assistant.text, "这是糯米的宠物信息")
        XCTAssertEqual(assistant.contentBlocks, blocks)
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

}
