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

        store.completeAttachmentSelection(
            source: .photoLibrary,
            image: image
        )

        XCTAssertNil(store.presentedAttachmentSource)
        XCTAssertEqual(store.selectedAttachment?.source, .photoLibrary)
        XCTAssertEqual(store.selectedAttachment?.title, "已添加 1 张图片")
    }

    @MainActor
    func testSelectingConversationHistoryLoadsMockMessages() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        let image = UIImage()
        let history = store.conversationHistories[1]
        store.draftText = "临时问题"
        store.completeAttachmentSelection(
            source: .camera,
            image: image
        )

        store.selectConversationHistory(history)

        XCTAssertEqual(store.selectedConversationHistoryID, history.id)
        XCTAssertEqual(store.messages, history.messages)
        XCTAssertTrue(store.draftText.isEmpty)
        XCTAssertNil(store.selectedAttachment)
        XCTAssertNil(store.selectedAttachmentImage)
        XCTAssertNil(store.pendingAction)
    }

    @MainActor
    func testNewConversationShowsDefaultTitleAndSuggestedPrompts() {
        let store = AIAssistantStore(
            context: AIAssistantEntryContext(selectedPetName: "雪球")
        )

        XCTAssertEqual(store.navigationTitle, "新对话")
        XCTAssertEqual(store.navigationSubtitle, "内容由毛球 AI 生成")
        XCTAssertTrue(store.shouldShowSuggestedPrompts)
        XCTAssertEqual(store.conversationHistoryNavigationTitle, "雪球的对话记录")
    }

    @MainActor
    func testSelectingHistoryUsesHistoryTitleAndHidesSuggestedPrompts() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        let history = store.conversationHistories[0]

        store.selectConversationHistory(history)

        XCTAssertEqual(store.navigationTitle, history.title)
        XCTAssertNil(store.navigationSubtitle)
        XCTAssertFalse(store.shouldShowSuggestedPrompts)
    }

    @MainActor
    func testSubmittingFirstMessageUsesQuestionAsConversationTitle() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.draftText = "下一次疫苗是什么时候？"

        store.submitDraft()

        XCTAssertEqual(store.navigationTitle, "下一次疫苗是什么时候？")
        XCTAssertNil(store.navigationSubtitle)
        XCTAssertFalse(store.shouldShowSuggestedPrompts)
    }
}
