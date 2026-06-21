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
}
