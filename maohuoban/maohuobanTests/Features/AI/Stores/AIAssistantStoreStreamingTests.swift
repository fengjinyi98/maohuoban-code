import XCTest
@testable import maohuoban

// AIAssistantStoreStreamingTests AI 助手流式回复测试
// 核心职责：
// - 验证 submitDraft 后通过 Repository 创建流式占位消息
// - 验证 triggerMockStreamingResponse 启动长文本流式
// - 验证流式完成后消息状态正确
@MainActor
final class AIAssistantStoreStreamingTests: XCTestCase {

    // MARK: - 通过 Repository 流式

    func testSendCreatesStreamingPlaceholder() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.basicStreamEvents())
        )
        store.draftText = "测试问题"

        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.messages.count, 2)
        guard store.messages.count >= 2 else { return }
        XCTAssertEqual(store.messages[0].role, .user)
        XCTAssertEqual(store.messages[1].role, .assistant)
        XCTAssertFalse(store.messages[1].isStreaming)
    }

    func testStreamingCompletesWithFullText() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.basicStreamEvents())
        )
        store.draftText = "疫苗"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        guard let lastMessage = store.messages.last else {
            XCTFail("没有消息")
            return
        }
        XCTAssertEqual(lastMessage.role, .assistant)
        XCTAssertFalse(lastMessage.isStreaming)
        XCTAssertEqual(lastMessage.text, "你好，毛球")
    }

    func testStreamingCompletionSetsReferenceChips() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.basicStreamEvents())
        )
        store.draftText = "疫苗"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        guard let lastMessage = store.messages.last else {
            XCTFail("没有消息")
            return
        }
        XCTAssertEqual(lastMessage.referenceChips, ["疫苗记录"])
    }

    func testStreamingCompletionSetsPendingAction() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.streamWithAction())
        )
        store.draftText = "疫苗"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(store.pendingAction)
        XCTAssertEqual(store.pendingAction?.title, "添加提醒")
    }

    // MARK: - Mock 流式（Debug）

    func testTriggerMockStreamingCreatesStreamingMessage() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.triggerMockStreamingResponse()

        XCTAssertEqual(store.messages.count, 1)
        guard let first = store.messages.first else { return }
        XCTAssertEqual(first.role, .assistant)
        XCTAssertTrue(first.isStreaming)
    }

    func testTriggerMockStreamingCompletesWithLongText() async {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.triggerMockStreamingResponse()

        try? await Task.sleep(nanoseconds: 10_000_000_000)

        guard let lastMessage = store.messages.last else {
            XCTFail("没有消息")
            return
        }
        XCTAssertFalse(lastMessage.isStreaming)
        XCTAssertGreaterThan(lastMessage.text.count, 500)
    }

    func testCanNotSendDuringStreaming() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.triggerMockStreamingResponse()

        XCTAssertFalse(store.canSendDraft)
        store.draftText = "测试"
        XCTAssertFalse(store.canSendDraft)
    }

    // MARK: - 流式期间禁用发送

    func testCanNotSendDuringRepositoryStreaming() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: Self.startedOnlyEvents())
        )
        store.draftText = "测试"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 50_000_000)

        store.draftText = "再发一条"
        XCTAssertFalse(store.canSendDraft)
    }

    // MARK: - Helpers

    private static func basicStreamEvents() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "疫苗咨询"),
            .delta(text: "你好"),
            .delta(text: "，毛球"),
            .messageCompleted(messageID: messageID, finalText: "你好，毛球", referenceChips: ["疫苗记录"]),
        ]
    }

    private static func startedOnlyEvents() -> [AIStreamEventDTO] {
        [
            .messageStarted(chatSessionID: UUID(), messageID: UUID(), title: "流式中"),
        ]
    }

    private static func streamWithAction() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        let actionID = UUID()
        let petID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "疫苗咨询"),
            .delta(text: "建议添加疫苗提醒"),
            .messageCompleted(messageID: messageID, finalText: "建议添加疫苗提醒", referenceChips: ["疫苗记录"]),
            .proposedAction(action: AIProposedActionDTO(
                id: actionID,
                actionKind: "reminder_creation",
                targetPetID: petID,
                confirmText: "添加提醒",
                riskLevel: "low",
                payload: nil
            )),
        ]
    }
}
