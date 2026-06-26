import XCTest
@testable import maohuoban

// AIAssistantStoreStreamingTests AI 助手流式回复集成测试
// 核心职责：
// - 锁定 submitDraft 后创建流式占位消息
// - 锁定 triggerMockStreamingResponse 启动长文本流式
// - 锁定流式完成后消息状态正确
@MainActor
final class AIAssistantStoreStreamingTests: XCTestCase {

    // MARK: - 流式占位

    func testSendCreatesStreamingPlaceholder() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.draftText = "测试问题"

        store.submitDraft()

        XCTAssertEqual(store.messages.count, 2)
        guard store.messages.count >= 2 else { return }
        XCTAssertEqual(store.messages[0].role, .user)
        XCTAssertEqual(store.messages[1].role, .assistant)
        XCTAssertTrue(store.messages[1].isStreaming)
    }

    func testTriggerMockStreamingCreatesStreamingMessage() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())

        store.triggerMockStreamingResponse()

        XCTAssertEqual(store.messages.count, 1)
        guard let first = store.messages.first else { return }
        XCTAssertEqual(first.role, .assistant)
        XCTAssertTrue(first.isStreaming)
    }

    // MARK: - 流式完成

    func testStreamingCompletesWithFullText() async {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.draftText = "疫苗"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        guard let lastMessage = store.messages.last else {
            XCTFail("没有消息")
            return
        }
        XCTAssertEqual(lastMessage.role, .assistant)
        XCTAssertFalse(lastMessage.isStreaming)
        XCTAssertFalse(lastMessage.text.isEmpty)
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

    // MARK: - 流式期间禁用发送

    func testCanNotSendDuringStreaming() {
        let store = AIAssistantStore(context: AIAssistantEntryContext())

        store.triggerMockStreamingResponse()

        XCTAssertFalse(store.canSendDraft)
        store.draftText = "测试"
        XCTAssertFalse(store.canSendDraft)
    }

    // MARK: - 流式完成后设置 pendingAction

    func testStreamingCompletionSetsPendingAction() async {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.draftText = "疫苗"
        store.submitDraft()

        XCTAssertNil(store.pendingAction)

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        XCTAssertNotNil(store.pendingAction)
    }

    // MARK: - 流式完成后引用标签正确

    func testStreamingCompletionSetsReferenceChips() async {
        let store = AIAssistantStore(context: AIAssistantEntryContext())
        store.draftText = "疫苗"
        store.submitDraft()

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        guard let lastMessage = store.messages.last else {
            XCTFail("没有消息")
            return
        }
        XCTAssertFalse(lastMessage.referenceChips.isEmpty)
    }
}
