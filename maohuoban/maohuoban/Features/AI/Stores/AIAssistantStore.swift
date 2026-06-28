import Foundation
import Observation
import UIKit

// AIAssistantStore AI 助手状态容器
// 核心职责：
// - 管理对话消息、输入草稿、待确认动作和历史列表
// - 通过 Repository 消费后端 SSE 流式事件
// - 保留 AIAssistantStreamingEngine 作为 UI 增量渲染层
@MainActor
@Observable
final class AIAssistantStore {
    let context: AIAssistantEntryContext
    let repository: AIAssistantRepository
    var draftText = ""
    var messages: [AIAssistantMessage]
    var pendingAction: AIAssistantProposedAction?
    var presentedAttachmentSource: AIAssistantAttachmentSource?
    var selectedAttachment: AIAssistantSelectedAttachment?
    var selectedAttachmentImage: UIImage?
    var selectedConversationHistoryID: String?
    var currentConversationTitle: String?
    var histories: [AIAssistantConversationHistory] = []
    var activeToolStatus: ActiveToolStatus?
    var pendingConfirmationTask: PendingConfirmationTask?
    @ObservationIgnored private(set) var streamingEngine = AIAssistantStreamingEngine()
    var streamingTask: Task<Void, Never>?
    var currentChatSessionID: String?

    static let networkFailureFallbackText = "网络连接失败，请检查网络后重试。"

    private(set) var isStreaming = false

    var streamingRevision: Int = 0

    init(
        context: AIAssistantEntryContext,
        repository: AIAssistantRepository = DefaultAIAssistantRepository()
    ) {
        self.context = context
        self.repository = repository
        self.messages = []
        configureStreamingEngine()
    }

    var canSendDraft: Bool {
        isStreaming == false && sanitizedDraft.isEmpty == false
    }

    var navigationTitle: String {
        currentConversationTitle ?? "新对话"
    }

    var navigationSubtitle: String? {
        currentConversationTitle == nil ? "内容由毛球 AI 生成" : nil
    }

    var shouldShowSuggestedPrompts: Bool {
        messages.isEmpty && currentConversationTitle == nil
    }

    var conversationHistoryNavigationTitle: String {
        "\(context.displayPetName)的对话记录"
    }

    func beginStreaming(messageID: UUID) {
        streamingEngine.begin(messageID: messageID)
        isStreaming = streamingEngine.isStreaming
    }

    func completeStreaming(finalText: String) {
        streamingEngine.complete(finalText: finalText)
        isStreaming = streamingEngine.isStreaming
    }

    func cancelStreaming() {
        streamingEngine.cancel()
        isStreaming = streamingEngine.isStreaming
    }
}
