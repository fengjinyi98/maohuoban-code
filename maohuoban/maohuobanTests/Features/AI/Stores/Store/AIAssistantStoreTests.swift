import UIKit
import XCTest
@testable import maohuoban

// AIAssistantStoreTests AI 助手状态测试
// 核心职责：
// - 固化系统媒体入口的前端状态流转
// - 防止相机和相册选择完成后丢失附件摘要
final class AIAssistantStoreTests: XCTestCase {
    @MainActor
    func testSelectingCameraPresentsCameraPicker() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())

        store.requestAttachmentSource(.camera)

        XCTAssertEqual(store.presentedAttachmentSource, .camera)
        XCTAssertNil(store.selectedAttachment)
    }

    @MainActor
    func testSelectingPhotoLibraryPresentsPhotoLibraryPicker() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())

        store.requestAttachmentSource(.photoLibrary)

        XCTAssertEqual(store.presentedAttachmentSource, .photoLibrary)
        XCTAssertNil(store.selectedAttachment)
    }

    @MainActor
    func testCancellingAttachmentSelectionClearsPresentedSource() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.requestAttachmentSource(.camera)

        store.cancelAttachmentSelection()

        XCTAssertNil(store.presentedAttachmentSource)
        XCTAssertNil(store.selectedAttachment)
    }

    @MainActor
    func testCompletingAttachmentSelectionStoresImageSummary() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        let image = UIImage()
        store.requestAttachmentSource(.photoLibrary)

        store.completeAttachmentSelection(source: .photoLibrary, image: image)

        XCTAssertNil(store.presentedAttachmentSource)
        XCTAssertEqual(store.selectedAttachment?.source, .photoLibrary)
        XCTAssertEqual(store.selectedAttachment?.title, "已添加 1 张图片")
    }

    @MainActor
    func testSelectingConversationHistoryLoadsMessages() {
        let history = AIAssistantConversationHistory(
            id: "test-session",
            title: "腹泻观察",
            subtitle: "昨天",
            messages: [
                AIAssistantMessage(role: .user, text: "拉肚子了"),
                AIAssistantMessage(role: .assistant, text: "先观察精神状态"),
            ],
            petAvatarURL: nil,
            petName: "毛球",
            petSpecies: .cat
        )
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository()
        )
        store.draftText = "临时问题"
        store.completeAttachmentSelection(source: .camera, image: UIImage())

        store.selectConversationHistory(history)

        XCTAssertEqual(store.selectedConversationHistoryID, history.id)
        XCTAssertEqual(store.messages, history.messages)
        XCTAssertTrue(store.draftText.isEmpty)
        XCTAssertNil(store.selectedAttachment)
        XCTAssertNil(store.selectedAttachmentImage)
        XCTAssertNil(store.pendingAction)
    }

    @MainActor
    func testLoadingSessionMessagesMapsCreatedAtToMessage() async {
        let sessionID = "test-session"
        let json = """
        [{"id":"00000000-0000-0000-0000-000000000000","role":"user","content":"昨天的记录","content_blocks":[],"created_at":"2026-07-04T08:59:00Z"}]
        """
        let data = json.data(using: .utf8)!
        let messages = try! JSONDecoder().decode([AIMessageDTO].self, from: data)
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(messages: messages)
        )
        store.currentChatSessionID = sessionID

        await store.loadSessionMessages(sessionID: sessionID)

        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].createdAt, MHBUTCDateDisplayFormatter.date(fromUTCString: "2026-07-04T08:59:00Z"))
    }

    @MainActor
    func testLoadingSessionMessagesSkipsSystemPlanningMessages() async {
        let sessionID = "test-session"
        let json = """
        [
            {"id":"00000000-0000-0000-0000-000000000000","role":"system","content":"异常主动追踪 planning：内部提示","content_blocks":[],"created_at":"2026-07-04T08:58:00Z"},
            {"id":"11111111-1111-1111-1111-111111111111","role":"assistant","content":"现在情况好转了吗？","content_blocks":[],"created_at":"2026-07-04T08:59:00Z"}
        ]
        """
        let data = json.data(using: .utf8)!
        let messages = try! JSONDecoder().decode([AIMessageDTO].self, from: data)
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(messages: messages)
        )
        store.currentChatSessionID = sessionID

        await store.loadSessionMessages(sessionID: sessionID)

        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].role, .assistant)
        XCTAssertEqual(store.messages[0].text, "现在情况好转了吗？")
    }

    @MainActor
    func testAbnormalEpisodeEntryRestoresExistingSessionAndMessages() async {
        let episodeID = "11111111-1111-1111-1111-111111111111"
        let sessionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let sessionJSON = """
        [{
            "id":"\(sessionID.uuidString)",
            "title":"异常追踪",
            "is_pinned":false,
            "chat_context_kind":"abnormal_episode_followup",
            "abnormal_episode_id":"\(episodeID)",
            "source_hint_id":"33333333-3333-3333-3333-333333333333",
            "agent_followup_id":"44444444-4444-4444-4444-444444444444",
            "subtitle":"今天",
            "pet_display_snapshot":null,
            "last_message_preview":"现在情况好转了吗？",
            "last_message_at":"2026-07-04T09:30:00Z"
        }]
        """
        let messageJSON = """
        [{"id":"55555555-5555-5555-5555-555555555555","role":"assistant","content":"现在情况好转了吗？","content_blocks":[],"created_at":"2026-07-04T09:30:00Z"}]
        """
        let sessions = try! JSONDecoder().decode([AIChatSessionDTO].self, from: sessionJSON.data(using: .utf8)!)
        let messages = try! JSONDecoder().decode([AIMessageDTO].self, from: messageJSON.data(using: .utf8)!)
        let repository = MockAIAssistantRepository(sessions: sessions, messages: messages)
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(
                selectedPetName: "雪球",
                abnormalEpisodeID: episodeID,
                abnormalEventID: "88888888-8888-8888-8888-888888888888",
                sourceHintID: "66666666-6666-6666-6666-666666666666",
                agentFollowupID: "77777777-7777-7777-7777-777777777777"
            ),
            repository: repository
        )

        await store.restoreAbnormalEpisodeConversationIfNeeded()

        XCTAssertEqual(repository.activatedAbnormalEpisodeIDs, [episodeID])
        XCTAssertEqual(store.currentChatSessionID, sessionID.uuidString)
        XCTAssertEqual(store.selectedConversationHistoryID, sessionID.uuidString)
        XCTAssertEqual(store.navigationTitle, "异常追踪")
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages[0].role, .assistant)
        XCTAssertEqual(store.messages[0].text, "现在情况好转了吗？")
    }

    @MainActor
    func testAbnormalEpisodeRestoredSessionSendsLatestAgentContext() async {
        let episodeID = "11111111-1111-1111-1111-111111111111"
        let sessionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let sessionJSON = """
        [{
            "id":"\(sessionID.uuidString)",
            "title":"异常追踪",
            "is_pinned":false,
            "chat_context_kind":"abnormal_episode_followup",
            "abnormal_episode_id":"\(episodeID)",
            "source_hint_id":"33333333-3333-3333-3333-333333333333",
            "agent_followup_id":"44444444-4444-4444-4444-444444444444",
            "subtitle":"今天",
            "pet_display_snapshot":null,
            "last_message_preview":"现在情况好转了吗？",
            "last_message_at":"2026-07-04T09:30:00Z"
        }]
        """
        let sessions = try! JSONDecoder().decode([AIChatSessionDTO].self, from: sessionJSON.data(using: .utf8)!)
        let repository = RecordingAIAssistantRepository(
            streamEvents: [
                .messageStarted(chatSessionID: sessionID, messageID: UUID(), title: "异常追踪"),
                .messageCompleted(messageID: UUID(), finalText: "已记录", referenceChips: [], references: []),
            ],
            sessions: sessions
        )
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(
                selectedPetName: "雪球",
                abnormalEpisodeID: episodeID,
                abnormalEventID: "88888888-8888-8888-8888-888888888888",
                sourceHintID: "66666666-6666-6666-6666-666666666666",
                agentFollowupID: "77777777-7777-7777-7777-777777777777"
            ),
            repository: repository
        )

        await store.restoreAbnormalEpisodeConversationIfNeeded()
        store.send("便便还是有点稀")
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(repository.streamChatSessionIDs.last, sessionID.uuidString)
        XCTAssertEqual(repository.streamEntryContexts.last?.abnormalEpisodeID, episodeID)
        XCTAssertEqual(repository.streamEntryContexts.last?.abnormalEventID, "88888888-8888-8888-8888-888888888888")
        XCTAssertEqual(repository.streamEntryContexts.last?.sourceHintID, "33333333-3333-3333-3333-333333333333")
        XCTAssertEqual(repository.streamEntryContexts.last?.agentFollowupID, "44444444-4444-4444-4444-444444444444")
    }

    @MainActor
    func testNewConversationShowsDefaultTitleAndSuggestedPrompts() {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(selectedPetName: "雪球"),
            repository: MockAIAssistantRepository()
        )

        XCTAssertEqual(store.navigationTitle, "新对话")
        XCTAssertEqual(store.navigationSubtitle, "内容由毛球 AI 生成")
        XCTAssertTrue(store.shouldShowSuggestedPrompts)
        XCTAssertEqual(store.conversationHistoryNavigationTitle, "雪球的对话记录")
    }

    @MainActor
    func testAbnormalEpisodeEntryExposesContextCard() {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(
                selectedPetName: "雪球",
                abnormalEpisodeID: "episode-1",
                abnormalEventID: "event-1",
                sourceHintID: "hint-1",
                agentFollowupID: "followup-1"
            ),
            repository: MockAIAssistantRepository()
        )

        XCTAssertEqual(
            store.abnormalEpisodeContextCard,
            AIAssistantAbnormalEpisodeContextCard(
                episodeID: "episode-1",
                eventID: "event-1",
                title: "本次异常上文",
                subtitle: "雪球的异常记录",
                petName: "雪球"
            )
        )
    }

    @MainActor
    func testDefaultEntryDoesNotExposeAbnormalEpisodeContextCard() {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(selectedPetName: "雪球"),
            repository: MockAIAssistantRepository()
        )

        XCTAssertNil(store.abnormalEpisodeContextCard)
    }

    @MainActor
    func testSelectingHistoryUsesHistoryTitleAndHidesSuggestedPrompts() {
        let history = AIAssistantConversationHistory(
            id: "test-session",
            title: "疫苗咨询",
            subtitle: "今天",
            messages: [AIAssistantMessage(role: .user, text: "疫苗")],
            petAvatarURL: nil,
            petName: "毛球",
            petSpecies: .cat
        )
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository()
        )

        store.selectConversationHistory(history)

        XCTAssertEqual(store.navigationTitle, history.title)
        XCTAssertNil(store.navigationSubtitle)
        XCTAssertFalse(store.shouldShowSuggestedPrompts)
    }

    @MainActor
    func testRenamingConversationHistoryUpdatesLocalListAndCurrentTitle() async {
        let history = AIAssistantConversationHistory(
            id: "test-session",
            title: "旧标题",
            subtitle: "今天",
            messages: [AIAssistantMessage(role: .user, text: "疫苗")],
            petAvatarURL: nil,
            petName: "毛球",
            petSpecies: .cat
        )
        let repository = MockAIAssistantRepository()
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: repository
        )
        store.histories = [history]
        store.selectConversationHistory(history)

        await store.renameConversationHistory(history, title: "新标题")

        XCTAssertEqual(repository.renamedSessionIDs, ["test-session"])
        XCTAssertEqual(repository.renamedTitles, ["新标题"])
        XCTAssertEqual(store.histories.first?.title, "新标题")
        XCTAssertEqual(store.navigationTitle, "新标题")
    }

    @MainActor
    func testPinningConversationHistoryMovesItToTop() async {
        let first = AIAssistantConversationHistory(
            id: "first-session",
            title: "第一条",
            subtitle: "今天",
            messages: [],
            petAvatarURL: nil,
            petName: "毛球",
            petSpecies: .cat
        )
        let second = AIAssistantConversationHistory(
            id: "second-session",
            title: "第二条",
            subtitle: "昨天",
            messages: [],
            petAvatarURL: nil,
            petName: "毛球",
            petSpecies: .cat
        )
        let repository = MockAIAssistantRepository()
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: repository
        )
        store.histories = [first, second]

        await store.setConversationHistoryPinned(second, isPinned: true)

        XCTAssertEqual(repository.pinnedSessionIDs, ["second-session"])
        XCTAssertEqual(repository.pinnedStates, [true])
        XCTAssertEqual(store.histories.map(\.id), ["second-session", "first-session"])
        XCTAssertTrue(store.histories[0].isPinned)
    }

    @MainActor
    func testDeletingSelectedConversationHistoryStartsNewConversation() async {
        let history = AIAssistantConversationHistory(
            id: "test-session",
            title: "准备删除",
            subtitle: "今天",
            messages: [AIAssistantMessage(role: .user, text: "疫苗")],
            petAvatarURL: nil,
            petName: "毛球",
            petSpecies: .cat
        )
        let repository = MockAIAssistantRepository()
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: repository
        )
        store.histories = [history]
        store.selectConversationHistory(history)

        await store.deleteConversationHistory(history)

        XCTAssertEqual(repository.deletedSessionIDs, ["test-session"])
        XCTAssertTrue(store.histories.isEmpty)
        XCTAssertNil(store.selectedConversationHistoryID)
        XCTAssertEqual(store.navigationTitle, "新对话")
        XCTAssertTrue(store.messages.isEmpty)
    }

    @MainActor
    func testSubmittingFirstMessageUsesQuestionAsConversationTitle() async {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(),
            repository: MockAIAssistantRepository(streamEvents: [
                .messageStarted(chatSessionID: UUID(), messageID: UUID(), title: "新对话"),
                .messageCompleted(
                    messageID: UUID(),
                    finalText: "ok",
                    referenceChips: [],
                    references: []
                ),
            ])
        )
        store.draftText = "下一次疫苗是什么时候？"

        store.submitDraft()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.navigationTitle, "下一次疫苗是什么时候？")
        XCTAssertNil(store.navigationSubtitle)
        XCTAssertFalse(store.shouldShowSuggestedPrompts)
    }

    @MainActor
    func testSecondMessageStartedDoesNotOverrideFirstMessageConversationTitle() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        let sessionID = UUID()

        store.send("第一条问题作为标题")
        store.handleStreamEvent(.messageStarted(chatSessionID: sessionID, messageID: UUID(), title: "第一条问题作为标题"))
        store.handleStreamEvent(.messageStarted(chatSessionID: sessionID, messageID: UUID(), title: "第二条问题不应覆盖"))

        XCTAssertEqual(store.navigationTitle, "第一条问题作为标题")
    }
}

// RecordingAIAssistantRepository AI 请求记录测试仓库
// 核心职责：
// - 捕获 Store 发起流式请求时携带的会话和入口上下文
// - 验证异常追踪入口恢复后继续使用最新 Agent 上下文
private final class RecordingAIAssistantRepository: AIAssistantRepository {
    var streamEvents: [AIStreamEventDTO]
    var sessions: [AIChatSessionDTO]
    var messages: [AIMessageDTO]
    var streamChatSessionIDs: [String?] = []
    var streamEntryContexts: [AIAssistantEntryContext] = []
    var activatedAbnormalEpisodeIDs: [String] = []

    init(
        streamEvents: [AIStreamEventDTO] = [],
        sessions: [AIChatSessionDTO] = [],
        messages: [AIMessageDTO] = []
    ) {
        self.streamEvents = streamEvents
        self.sessions = sessions
        self.messages = messages
    }

    func openChatStream(
        message: String,
        selectedPetID: String?,
        surface: String,
        chatSessionID: String?,
        entryContext: AIAssistantEntryContext
    ) -> AsyncThrowingStream<AIStreamEventDTO, Error> {
        streamChatSessionIDs.append(chatSessionID)
        streamEntryContexts.append(entryContext)
        return AsyncThrowingStream { continuation in
            for event in streamEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func fetchChatSessions() async throws(MHBAPIError) -> MHBAPIResponse<[AIChatSessionDTO]> {
        MHBAPIResponse(success: true, code: "ai.sessions_loaded", message: "ok", data: sessions)
    }

    func activateAbnormalEpisodeSession(
        abnormalEpisodeID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionDTO> {
        activatedAbnormalEpisodeIDs.append(abnormalEpisodeID)
        guard let session = sessions.first(where: { $0.abnormalEpisodeID == abnormalEpisodeID }) else {
            throw .business(code: "ai.session_not_found", message: "异常追踪会话不存在", statusCode: 404)
        }
        return MHBAPIResponse(success: true, code: "ai.session_activated", message: "ok", data: session)
    }

    func fetchSessionMessages(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<[AIMessageDTO]> {
        MHBAPIResponse(success: true, code: "ai.messages_loaded", message: "ok", data: messages)
    }

    func renameChatSession(
        sessionID: String,
        title: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前测试仓库不支持重命名", statusCode: 400)
    }

    func setChatSessionPinned(
        sessionID: String,
        isPinned: Bool
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前测试仓库不支持置顶", statusCode: 400)
    }

    func deleteChatSession(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<AIChatSessionMutationResultDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前测试仓库不支持删除", statusCode: 400)
    }

    func confirmProposedAction(
        _ action: AIAssistantProposedAction
    ) async throws(MHBAPIError) -> MHBAPIResponse<AIAssistantActionConfirmationResultDTO> {
        throw .business(code: "ai.unsupported_action", message: "当前测试仓库不支持确认", statusCode: 400)
    }
}
