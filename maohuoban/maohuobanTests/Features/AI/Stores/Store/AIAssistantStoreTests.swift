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
}
