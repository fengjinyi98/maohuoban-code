import Foundation
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
        debugLog("submitDraft_enter promptEmpty=\(prompt.isEmpty) promptLen=\(prompt.count) canSendDraft=\(canSendDraft)")
        guard prompt.isEmpty == false else { return }
        draftText = ""
        debugLog("submitDraft_after_clear")
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
                await AIAssistantDiagnostics.recordHistorySessionsLoaded(
                    sessionCount: histories.count,
                    pinnedCount: histories.filter(\.isPinned).count,
                    petSnapshotCount: data.filter { $0.petDisplaySnapshot != nil }.count
                )
            }
        } catch {
            histories = []
            await AIAssistantDiagnostics.recordHistorySessionsLoaded(
                sessionCount: 0,
                pinnedCount: 0,
                petSnapshotCount: 0
            )
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
            await AIAssistantDiagnostics.recordHistoryMutationCompleted(
                action: "rename",
                sessionID: history.id,
                success: true
            )
        } catch {
            await AIAssistantDiagnostics.recordHistoryMutationCompleted(
                action: "rename",
                sessionID: history.id,
                success: false
            )
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
            await AIAssistantDiagnostics.recordHistoryMutationCompleted(
                action: "pin",
                sessionID: history.id,
                success: true
            )
        } catch {
            await AIAssistantDiagnostics.recordHistoryMutationCompleted(
                action: "pin",
                sessionID: history.id,
                success: false
            )
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
            await AIAssistantDiagnostics.recordHistoryMutationCompleted(
                action: "delete",
                sessionID: history.id,
                success: true
            )
        } catch {
            await AIAssistantDiagnostics.recordHistoryMutationCompleted(
                action: "delete",
                sessionID: history.id,
                success: false
            )
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
        debugLog(
            "applyStreamingFlush_enter messageID=\(String(messageID.uuidString.prefix(8))) textLen=\(text.count) nextIsStreaming=\(isStreaming)"
        )
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].text = text
        messages[index].isStreaming = isStreaming
        streamingRevision += 1
        debugLog("applyStreamingFlush_after revision=\(streamingRevision)")
    }

    private func send(_ text: String) {
        debugLog("send_enter textLen=\(text.count)")
        if currentConversationTitle == nil {
            currentConversationTitle = makeConversationTitle(from: text)
        }

        let submittingSessionID = currentChatSessionID
        Task {
            await AIAssistantDiagnostics.recordChatSubmit(
                message: text,
                selectedPetID: context.selectedPetID,
                chatSessionID: submittingSessionID
            )
        }

        messages.append(AIAssistantMessage(role: .user, text: text))
        clearAttachment()
        let assistantReplyStartIndex = messages.count
        let placeholder = AIAssistantMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(placeholder)
        debugLog(
            "send_placeholder_appended placeholderID=\(String(placeholder.id.uuidString.prefix(8))) assistantReplyStartIndex=\(assistantReplyStartIndex)"
        )
        streamingEngine.begin(messageID: placeholder.id)
        debugLog("send_after_begin")

        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }
            self.debugLog("stream_task_start sessionPrefix=\(String((self.currentChatSessionID ?? "").prefix(8)))")
            let stream = self.repository.openChatStream(
                message: text,
                selectedPetID: self.context.selectedPetID,
                surface: "home_private",
                chatSessionID: self.currentChatSessionID
            )
            do {
                for try await event in stream {
                    if Task.isCancelled { return }
                    self.debugLog("stream_event_loop event=\(self.streamEventDebugName(event))")
                    self.handleStreamEvent(event)
                }
                if Task.isCancelled { return }
                self.debugLog("stream_loop_finished_before_empty_check")
                self.finishStreamIfAssistantReplyMissing(after: assistantReplyStartIndex)
                await AIAssistantDiagnostics.recordStreamCompleted(
                    messageCount: self.messages.count,
                    assistantReplyPresent: self.hasCompletedAssistantReply(after: assistantReplyStartIndex),
                    isStreaming: self.isStreaming
                )
                self.debugLog("stream_task_completed")
            } catch {
                self.debugLog("stream_task_catch error=\(self.streamErrorDiagnosticsCode(error))")
                self.handleStreamError(error)
            }
        }
    }

    private func handleStreamEvent(_ event: AIStreamEventDTO) {
        debugLog("handleStreamEvent_enter event=\(streamEventDebugName(event))")
        Task {
            await AIAssistantDiagnostics.recordStreamEventConsumed(
                event,
                messageCount: messages.count,
                isStreaming: isStreaming
            )
        }

        switch event {
        case .messageStarted(let chatSessionID, _, let title):
            debugLog("handle_messageStarted sessionPrefix=\(String(chatSessionID.uuidString.prefix(8)))")
            currentChatSessionID = chatSessionID.uuidString
            if !title.isEmpty && title != "新对话" {
                currentConversationTitle = title
            } else if currentConversationTitle == nil {
                currentConversationTitle = title
            }
            ensureStreamingPlaceholderExists()

        case .delta(let text):
            streamingEngine.appendDelta(text)
            streamingEngine.flush()
            streamingRevision += 1

        case .messageCompleted(_, let finalText, let chips):
            applyCompletedAssistantMessage(finalText: finalText, referenceChips: chips)

        case .proposedAction(let action):
            pendingAction = AIAssistantProposedAction(from: action)

        case .error(let code, _, let retryable, let safeFallbackText):
            debugLog(
                "handle_error_before_finish code=\(code) retryable=\(retryable) safeTextPresent=\(safeFallbackText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)"
            )
            recordStreamIssue(
                source: "backend_sse_error",
                code: code,
                retryable: retryable,
                hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
            )
            finishBackendError(safeFallbackText: safeFallbackText)
            debugLog("handle_error_after_finish code=\(code)")
        }
    }

    private func ensureStreamingPlaceholderExists() {
        guard streamingEngine.activeMessageID == nil else {
            debugLog("ensure_placeholder_skip_active")
            return
        }
        debugLog("ensure_placeholder_create")
        let placeholder = AIAssistantMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(placeholder)
        streamingEngine.begin(messageID: placeholder.id)
        streamingRevision += 1
        debugLog("ensure_placeholder_after revision=\(streamingRevision)")
    }

    private func applyCompletedAssistantMessage(finalText: String, referenceChips: [String]) {
        debugLog("applyCompleted_enter finalLen=\(finalText.count) chips=\(referenceChips.count)")
        let activeMessageID = streamingEngine.activeMessageID
        if let activeMessageID {
            streamingEngine.complete(finalText: finalText)
            if let index = messages.firstIndex(where: { $0.id == activeMessageID }) {
                messages[index].referenceChips = referenceChips
            }
            streamingRevision += 1
            Task {
                await AIAssistantDiagnostics.recordAssistantFinalized(
                    source: "message_completed",
                    text: finalText,
                    referenceChipCount: referenceChips.count
                )
            }
            return
        }

        streamingEngine.cancel()
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
            messages[index].text = finalText
            messages[index].referenceChips = referenceChips
            messages[index].isStreaming = false
        } else {
            messages.append(
                AIAssistantMessage(
                    role: .assistant,
                    text: finalText,
                    referenceChips: referenceChips
                )
            )
        }
        streamingRevision += 1
        Task {
            await AIAssistantDiagnostics.recordAssistantFinalized(
                source: "message_completed",
                text: finalText,
                referenceChipCount: referenceChips.count
            )
        }
        debugLog("applyCompleted_after")
    }

    private func handleStreamError(_ error: Error) {
        if error is CancellationError { return }
        debugLog("handleStreamError_enter code=\(streamErrorDiagnosticsCode(error))")
        recordStreamIssue(
            source: "local_stream_error",
            code: streamErrorDiagnosticsCode(error),
            hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
        )
        replaceStreamingOrAppendAssistantMessage(Self.networkFailureFallbackText)
        Task {
            await AIAssistantDiagnostics.recordAssistantFinalized(
                source: "local_stream_error",
                text: Self.networkFailureFallbackText,
                referenceChipCount: 0
            )
        }
        debugLog("handleStreamError_after")
    }

    private func finishBackendError(safeFallbackText: String?) {
        let trimmedText = safeFallbackText?.trimmingCharacters(in: .whitespacesAndNewlines)
        debugLog("finishBackendError_enter safeTextLen=\(trimmedText?.count ?? 0)")
        guard let trimmedText, trimmedText.isEmpty == false else {
            discardCurrentAssistantReply()
            debugLog("finishBackendError_discarded_empty_safe_text")
            return
        }
        replaceStreamingOrAppendAssistantMessage(trimmedText)
        Task {
            await AIAssistantDiagnostics.recordAssistantFinalized(
                source: "backend_sse_error",
                text: trimmedText,
                referenceChipCount: 0
            )
        }
        debugLog("finishBackendError_after_replace")
    }

    private func replaceStreamingOrAppendAssistantMessage(_ text: String) {
        debugLog("replaceStreaming_enter textLen=\(text.count)")
        streamingEngine.cancel()
        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            debugLog("replaceStreaming_reuse_index=\(index)")
            messages[index].text = text
            messages[index].isStreaming = false
        } else {
            debugLog("replaceStreaming_append_new")
            messages.append(AIAssistantMessage(role: .assistant, text: text))
        }
        streamingRevision += 1
        debugLog("replaceStreaming_after revision=\(streamingRevision)")
    }

    private func finishStreamIfAssistantReplyMissing(after startIndex: Int) {
        guard hasCompletedAssistantReply(after: startIndex) == false else { return }
        debugLog("finishStreamIfMissing_enter startIndex=\(startIndex)")
        recordStreamIssue(
            source: "local_empty_stream",
            code: "ai.empty_stream",
            hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
        )
        discardIncompleteAssistantReplies(after: startIndex)
        debugLog("finishStreamIfMissing_after")
    }

    private func hasCompletedAssistantReply(after startIndex: Int) -> Bool {
        messages.enumerated().contains { index, message in
            index >= startIndex
                && message.role == .assistant
                && message.isStreaming == false
                && message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    private func discardIncompleteAssistantReplies(after startIndex: Int) {
        debugLog("discardIncomplete_enter startIndex=\(startIndex)")
        let hadActiveStream = streamingEngine.isStreaming
        streamingEngine.cancel()
        let originalCount = messages.count
        messages = messages.enumerated().compactMap { index, message in
            guard index >= startIndex,
                  message.role == .assistant,
                  message.isStreaming || message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return message
            }
            return nil
        }
        if hadActiveStream || messages.count != originalCount {
            streamingRevision += 1
        }
        debugLog("discardIncomplete_after originalCount=\(originalCount) revision=\(streamingRevision)")
    }

    private func discardCurrentAssistantReply() {
        debugLog("discardCurrent_enter")
        let activeMessageID = streamingEngine.activeMessageID
        let hadActiveStream = streamingEngine.isStreaming
        streamingEngine.cancel()
        let originalCount = messages.count
        if let activeMessageID {
            messages.removeAll { $0.id == activeMessageID }
        } else {
            messages.removeAll { $0.isStreaming }
        }
        if hadActiveStream || messages.count != originalCount {
            streamingRevision += 1
        }
        debugLog("discardCurrent_after originalCount=\(originalCount) revision=\(streamingRevision)")
    }

    private func recordStreamIssue(
        source: String,
        code: String,
        retryable: Bool? = nil,
        hasStreamingPlaceholder: Bool
    ) {
        Task {
            await AIAssistantDiagnostics.recordStreamIssue(
                source: source,
                code: code,
                retryable: retryable,
                hasStreamingPlaceholder: hasStreamingPlaceholder
            )
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

    private func streamEventDebugName(_ event: AIStreamEventDTO) -> String {
        switch event {
        case .messageStarted:
            "message_started"
        case .delta:
            "delta"
        case .messageCompleted:
            "message_completed"
        case .proposedAction:
            "proposed_action"
        case .error(let code, _, _, _):
            "error:\(code)"
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        let activePrefix = streamingEngine.activeMessageID.map { String($0.uuidString.prefix(8)) } ?? "nil"
        let streamingMessageCount = messages.filter(\.isStreaming).count
        print(
            "[DEBUG:AISendLock] store \(message) isStreaming=\(isStreaming) activeMessageID=\(activePrefix) draftLen=\(draftText.count) messageCount=\(messages.count) streamingMessages=\(streamingMessageCount) revision=\(streamingRevision)"
        )
        #endif
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
                await AIAssistantDiagnostics.recordHistoryMessagesLoaded(
                    sessionID: sessionID,
                    messageCount: messages.count
                )
            }
        } catch {
            // 保持预览消息
            await AIAssistantDiagnostics.recordHistoryMessagesLoaded(
                sessionID: sessionID,
                messageCount: 0
            )
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
