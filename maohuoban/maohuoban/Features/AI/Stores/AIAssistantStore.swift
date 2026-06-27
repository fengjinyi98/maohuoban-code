import Foundation
import MaohuobanDiagnostics
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
    private(set) var streamingEngine = AIAssistantStreamingEngine()
    private var streamingTask: Task<Void, Never>?
    private var currentChatSessionID: String?

    private static let genericFallbackText = "暂时无法获取回答，请稍后重试。"
    private static let networkFailureFallbackText = "网络连接失败，请检查网络后重试。"

    var isStreaming: Bool {
        streamingEngine.isStreaming
    }

    private(set) var streamingRevision: Int = 0

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

    func submitDraft() {
        let prompt = sanitizedDraft
        guard prompt.isEmpty == false else { return }
        draftText = ""
        send(prompt)
    }

    func sendSuggestedPrompt(_ prompt: AIAssistantSuggestedPrompt) {
        send(prompt.prompt)
    }

    func requestAttachmentSource(_ source: AIAssistantAttachmentSource) {
        presentedAttachmentSource = source
    }

    func cancelAttachmentSelection() {
        presentedAttachmentSource = nil
    }

    func completeAttachmentSelection(source: AIAssistantAttachmentSource, image: UIImage) {
        presentedAttachmentSource = nil
        selectedAttachmentImage = image
        selectedAttachment = AIAssistantSelectedAttachment(source: source, title: "已添加 1 张图片")
    }

    func clearAttachment() {
        selectedAttachment = nil
        selectedAttachmentImage = nil
        presentedAttachmentSource = nil
    }

    func selectConversationHistory(_ history: AIAssistantConversationHistory) {
        selectedConversationHistoryID = history.id
        currentConversationTitle = history.title
        currentChatSessionID = history.id
        draftText = ""
        pendingAction = nil
        clearAttachment()
        messages = history.messages
        Task { [weak self] in
            await self?.loadSessionMessages(sessionID: history.id)
        }
    }

    func startNewConversation() {
        selectedConversationHistoryID = nil
        currentConversationTitle = nil
        currentChatSessionID = nil
        draftText = ""
        pendingAction = nil
        clearAttachment()
        messages = []
    }

    func loadHistories() async {
        do {
            let response = try await repository.fetchChatSessions()
            if let data = response.data {
                histories = data.map { AIAssistantConversationHistory(from: $0) }
            }
        } catch {
            histories = []
        }
    }

    func renameConversationHistory(
        _ history: AIAssistantConversationHistory,
        title: String
    ) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else { return }

        do {
            let response = try await repository.renameChatSession(
                sessionID: history.id,
                title: trimmedTitle
            )
            let updatedTitle = response.data?.title ?? trimmedTitle
            updateHistory(history.id) { history in
                history.updating(title: updatedTitle)
            }
            if selectedConversationHistoryID == history.id {
                currentConversationTitle = updatedTitle
            }
        } catch {
            return
        }
    }

    func setConversationHistoryPinned(
        _ history: AIAssistantConversationHistory,
        isPinned: Bool
    ) async {
        do {
            let response = try await repository.setChatSessionPinned(
                sessionID: history.id,
                isPinned: isPinned
            )
            let updatedPinnedState = response.data?.isPinned ?? isPinned
            updateHistory(history.id) { history in
                history.updating(isPinned: updatedPinnedState)
            }
            sortHistoriesByPinnedState()
        } catch {
            return
        }
    }

    func deleteConversationHistory(_ history: AIAssistantConversationHistory) async {
        do {
            _ = try await repository.deleteChatSession(sessionID: history.id)
            histories.removeAll { $0.id == history.id }
            if selectedConversationHistoryID == history.id || currentChatSessionID == history.id {
                startNewConversation()
            }
        } catch {
            return
        }
    }

    func confirmPendingAction() {
        guard let pendingAction else { return }
        Task { [weak self] in
            await self?.confirm(pendingAction)
        }
    }

    func cancelPendingAction() {
        pendingAction = nil
        messages.append(
            AIAssistantMessage(role: .assistant, text: "已取消这次建议动作，对话记录会继续保留。")
        )
    }

    // MARK: - Private

    private var sanitizedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureStreamingEngine() {
        streamingEngine.onFlush = { [weak self] messageID, text, isStreaming in
            self?.applyStreamingFlush(messageID: messageID, text: text, isStreaming: isStreaming)
        }
    }

    private func applyStreamingFlush(messageID: UUID, text: String, isStreaming: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].text = text
        messages[index].isStreaming = isStreaming
        streamingRevision += 1
    }

    private func send(_ text: String) {
        if currentConversationTitle == nil {
            currentConversationTitle = makeConversationTitle(from: text)
        }

        messages.append(AIAssistantMessage(role: .user, text: text))
        clearAttachment()
        let assistantReplyStartIndex = messages.count

        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }
            let stream = self.repository.openChatStream(
                message: text,
                selectedPetID: self.context.selectedPetID,
                surface: "home_private",
                chatSessionID: self.currentChatSessionID
            )
            do {
                for try await event in stream {
                    if Task.isCancelled { return }
                    self.handleStreamEvent(event)
                }
                if Task.isCancelled { return }
                self.appendFallbackIfAssistantReplyMissing(after: assistantReplyStartIndex)
            } catch {
                self.handleStreamError(error)
            }
        }
    }

    private func handleStreamEvent(_ event: AIStreamEventDTO) {
        switch event {
        case .messageStarted(let chatSessionID, _, let title):
            currentChatSessionID = chatSessionID.uuidString
            if !title.isEmpty && title != "新对话" {
                currentConversationTitle = title
            } else if currentConversationTitle == nil {
                currentConversationTitle = title
            }
            let placeholder = AIAssistantMessage(role: .assistant, text: "", isStreaming: true)
            messages.append(placeholder)
            streamingEngine.begin(messageID: placeholder.id)

        case .delta(let text):
            streamingEngine.appendDelta(text)
            streamingEngine.flush()
            streamingRevision += 1

        case .messageCompleted(_, let finalText, let chips):
            let activeMessageID = streamingEngine.activeMessageID
            streamingEngine.complete(finalText: finalText)
            if let activeMessageID,
               let index = messages.firstIndex(where: { $0.id == activeMessageID }) {
                messages[index].referenceChips = chips
            }
            streamingRevision += 1

        case .proposedAction(let action):
            pendingAction = AIAssistantProposedAction(from: action)

        case .error(let code, _, let retryable, let safeFallbackText):
            recordStreamFallback(
                source: "backend_sse_error",
                code: code,
                retryable: retryable,
                hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
            )
            replaceStreamingOrAppendFallback(safeFallbackText ?? Self.genericFallbackText)
        }
    }

    private func handleStreamError(_ error: Error) {
        if error is CancellationError { return }
        recordStreamFallback(
            source: "local_stream_error",
            code: streamErrorDiagnosticsCode(error),
            hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
        )
        replaceStreamingOrAppendFallback(Self.networkFailureFallbackText)
    }

    private func replaceStreamingOrAppendFallback(_ text: String) {
        streamingEngine.cancel()
        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            messages[index].text = text
            messages[index].isStreaming = false
        } else {
            messages.append(AIAssistantMessage(role: .assistant, text: text))
        }
        streamingRevision += 1
    }

    private func appendFallbackIfAssistantReplyMissing(after startIndex: Int) {
        let hasAssistantReply = messages.enumerated().contains { index, message in
            index >= startIndex && message.role == .assistant
        }
        guard hasAssistantReply == false else { return }
        recordStreamFallback(
            source: "local_empty_stream",
            code: "ai.empty_stream",
            hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
        )
        replaceStreamingOrAppendFallback(Self.genericFallbackText)
    }

    private func recordStreamFallback(
        source: String,
        code: String,
        retryable: Bool? = nil,
        hasStreamingPlaceholder: Bool
    ) {
        var properties: DiagnosticProperties = [
            "source": .string(source),
            "code": .string(code),
            "has_streaming_placeholder": .bool(hasStreamingPlaceholder)
        ]
        if let retryable {
            properties["retryable"] = .bool(retryable)
        }
        Task {
            await Diagnostics.track("ai.chat.stream.fallback", properties: properties)
        }
    }

    private func streamErrorDiagnosticsCode(_ error: Error) -> String {
        guard let apiError = error as? MHBAPIError else {
            return String(describing: type(of: error))
        }
        switch apiError {
        case .business(let code, _, _):
            return code
        case .transport:
            return "transport"
        case .decoding:
            return "decoding"
        case .invalidResponse:
            return "invalid_response"
        }
    }

    private func confirm(_ action: AIAssistantProposedAction) async {
        do {
            _ = try await repository.confirmProposedAction(action)
            messages.append(AIAssistantMessage(role: .user, text: action.confirmTitle))
            messages.append(AIAssistantMessage(role: .assistant, text: "已完成这次确认。"))
            pendingAction = nil
        } catch {
            messages.append(
                AIAssistantMessage(
                    role: .assistant,
                    text: "确认失败，请稍后重试。",
                    referenceChips: ["确认未完成"]
                )
            )
        }
    }

    private func loadSessionMessages(sessionID: String) async {
        do {
            let response = try await repository.fetchSessionMessages(sessionID: sessionID)
            guard currentChatSessionID == sessionID else { return }
            if let data = response.data {
                messages = data.map { dto in
                    AIAssistantMessage(
                        role: dto.role == "user" ? .user : .assistant,
                        text: dto.content
                    )
                }
            }
        } catch {
            // 保持预览消息
        }
    }

    private func makeConversationTitle(from text: String) -> String {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > 18 else { return title }
        return "\(title.prefix(18))..."
    }

    private func updateHistory(
        _ id: String,
        transform: (AIAssistantConversationHistory) -> AIAssistantConversationHistory
    ) {
        guard let index = histories.firstIndex(where: { $0.id == id }) else { return }
        histories[index] = transform(histories[index])
    }

    private func sortHistoriesByPinnedState() {
        let pinned = histories.filter(\.isPinned)
        let unpinned = histories.filter { !$0.isPinned }
        histories = pinned + unpinned
    }
}

// MARK: - Debug mock 流式

#if DEBUG
extension AIAssistantStore {
    func triggerMockStreamingResponse() {
        startMockStreamingResponse(
            fullText: AIAssistantMockContent.longStreamingText,
            referenceChips: ["意图识别", "受控工具", "来源校验"],
            action: nil
        )
    }

    private func startMockStreamingResponse(
        fullText: String,
        referenceChips: [String],
        action: AIAssistantProposedAction?
    ) {
        streamingTask?.cancel()

        let placeholder = AIAssistantMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(placeholder)
        streamingEngine.begin(messageID: placeholder.id)

        let messageID = placeholder.id
        let chunks = splitIntoChunks(fullText)

        streamingTask = Task { [weak self] in
            guard let self else { return }
            for chunk in chunks {
                if Task.isCancelled { return }
                self.streamingEngine.appendDelta(chunk)
                self.streamingEngine.flush()
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
            self.streamingEngine.complete(finalText: fullText)
            if let index = self.messages.firstIndex(where: { $0.id == messageID }) {
                self.messages[index].referenceChips = referenceChips
            }
            self.pendingAction = action
            self.streamingRevision += 1
        }
    }

    private func splitIntoChunks(_ text: String) -> [String] {
        let chunkSize = 8
        var chunks: [String] = []
        var accumulated = ""
        for char in text {
            accumulated.append(char)
            if accumulated.count >= chunkSize {
                chunks.append(accumulated)
                accumulated = ""
            }
        }
        if !accumulated.isEmpty {
            chunks.append(accumulated)
        }
        return chunks
    }
}
#endif
