import Observation
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
            repository: PendingStreamingAIAssistantRepository()
        )
        store.draftText = "测试"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 50_000_000)

        store.draftText = "再发一条"
        XCTAssertFalse(store.canSendDraft)
    }

    func testCanSendDraftNotifiesObservationWhenStreamCompletesWithPreparedDraft() async {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.ensureStreamingPlaceholderExists()
        store.draftText = "再发一条"
        XCTAssertFalse(store.canSendDraft)

        let probe = ObservationExpectationProbe(
            expectation: expectation(description: "canSendDraft should notify observers")
        )

        withObservationTracking {
            _ = store.canSendDraft
        } onChange: {
            probe.fulfill()
        }

        store.applyCompletedAssistantMessage(
            finalText: "已完成",
            referenceChips: [],
            references: []
        )

        await fulfillment(of: [probe.expectation], timeout: 1)
        XCTAssertTrue(store.canSendDraft)
    }

    func testStreamingStateNotifiesObservationWhenStreamStarts() async {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        let probe = ObservationExpectationProbe(
            expectation: expectation(description: "isStreaming should notify observers")
        )

        withObservationTracking {
            _ = store.isStreaming
        } onChange: {
            probe.fulfill()
        }

        store.ensureStreamingPlaceholderExists()

        await fulfillment(of: [probe.expectation], timeout: 1)
    }

    // MARK: - Helpers

    private static func basicStreamEvents() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "疫苗咨询"),
            .delta(text: "你好"),
            .delta(text: "，毛球"),
            .messageCompleted(
                messageID: messageID,
                finalText: "你好，毛球",
                referenceChips: ["疫苗记录"],
                references: []
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
            .delta(text: "建议添加疫苗提醒"),
            .messageCompleted(
                messageID: messageID,
                finalText: "建议添加疫苗提醒",
                referenceChips: ["疫苗记录"],
                references: []
            ),
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

// ObservationExpectationProbe Observation 测试探针
// 核心职责：
// - 在 @Sendable onChange 闭包中安全持有 XCTestExpectation
// - 避免测试代码泄露到业务实现
private final class ObservationExpectationProbe: @unchecked Sendable {
    let expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func fulfill() {
        expectation.fulfill()
    }
}

// PendingStreamingAIAssistantRepository 挂起流式测试仓库
// 核心职责：
// - 模拟后端 SSE 请求已经发起但尚未结束的窗口
// - 验证 Store 在真实流式等待期间保持发送禁用
private final class PendingStreamingAIAssistantRepository: AIAssistantRepository {
    private var continuation: AsyncThrowingStream<AIStreamEventDTO, Error>.Continuation?

    deinit {
        continuation?.finish()
    }

    func openChatStream(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?,
        entryContext: AIAssistantEntryContext
    ) -> AsyncThrowingStream<AIStreamEventDTO, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func fetchChatSessions() async throws(MHBAPIError) -> MHBAPIResponse<[AIChatSessionDTO]> {
        MHBAPIResponse(success: true, code: "ai.sessions_loaded", message: "ok", data: [])
    }

    func activateAbnormalEpisodeSession(
        abnormalEpisodeID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持激活异常追踪会话",
            statusCode: 400
        )
    }

    func fetchSessionMessages(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<[AIMessageDTO]> {
        MHBAPIResponse(success: true, code: "ai.messages_loaded", message: "ok", data: [])
    }

    func renameChatSession(
        sessionID: String,
        title: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持重命名",
            statusCode: 400
        )
    }

    func setChatSessionPinned(
        sessionID: String,
        isPinned: Bool
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持置顶",
            statusCode: 400
        )
    }

    func deleteChatSession(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持删除",
            statusCode: 400
        )
    }

    func confirmProposedAction(
        _ action: AIAssistantProposedAction
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIAssistantActionConfirmationResultDTO> {
        throw .business(
            code: "ai.unsupported_action",
            message: "当前测试仓库不支持确认",
            statusCode: 400
        )
    }
}
