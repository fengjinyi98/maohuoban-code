import Foundation

extension AIAssistantStore {
    var sanitizedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func configureStreamingEngine() {
        streamingEngine.onFlush = { [weak self] messageID, text, isStreaming in
            self?.applyStreamingFlush(messageID: messageID, text: text, isStreaming: isStreaming)
        }
    }

    func applyStreamingFlush(messageID: UUID, text: String, isStreaming: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            mhbTempFrontendLog(
                "stage=store.flush.missing_message message_id=\(messageID) text_chars=\(text.count) is_streaming=\(isStreaming) message_count=\(messages.count)"
            )
            return
        }
        mhbTempFrontendLog(
            "stage=store.flush.apply message_id=\(messageID) index=\(index) text_chars=\(text.count) trimmed_empty=\(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) is_streaming=\(isStreaming)"
        )
        messages[index].text = text
        messages[index].isStreaming = isStreaming
        streamingRevision += 1
    }

    func send(_ text: String) {
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
        mhbTempFrontendLog(
            "stage=store.send.placeholder placeholder_id=\(placeholder.id) start_index=\(assistantReplyStartIndex) message_len=\(text.count) current_session_present=\(currentChatSessionID != nil) selected_pet_present=\(context.selectedPetID != nil) message_count=\(messages.count)"
        )
        pendingReferenceChips = []
        beginStreaming(messageID: placeholder.id)

        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }
            let completionSequenceBeforeStream = self.assistantReplyCompletionSequence
            var didReceiveAssistantReply = false
            let stream = self.repository.openChatStream(
                message: text,
                selectedPetID: self.context.selectedPetID,
                surface: "home_private",
                chatSessionID: self.currentChatSessionID
            )
            do {
                for try await event in stream {
                    if Task.isCancelled { return }
                    mhbTempFrontendLog(
                        "stage=store.stream.event summary=\(event.mhbTempSummary) message_count=\(self.messages.count) is_streaming=\(self.isStreaming) active_id=\(String(describing: self.streamingEngine.activeMessageID))"
                    )
                    self.handleStreamEvent(event)
                    if self.streamEventCompletesAssistantReply(event) {
                        didReceiveAssistantReply = true
                    }
                }
                if Task.isCancelled { return }
                let didCompleteAssistantReply = didReceiveAssistantReply
                    || self.assistantReplyCompletionSequence > completionSequenceBeforeStream
                self.finishStreamIfAssistantReplyMissing(
                    after: assistantReplyStartIndex,
                    placeholderID: placeholder.id,
                    didReceiveAssistantReply: didCompleteAssistantReply
                )
            } catch {
                mhbTempFrontendLog(
                    "stage=store.stream.catch error_type=\(String(describing: type(of: error))) message_count=\(self.messages.count) is_streaming=\(self.isStreaming)"
                )
                self.handleStreamError(error)
            }
        }
    }

    func handleStreamEvent(_ event: AIStreamEventDTO) {
        Task {
            await AIAssistantDiagnostics.recordStreamEventConsumed(
                event,
                messageCount: messages.count,
                isStreaming: isStreaming
            )
        }

        switch event {
        case .messageStarted(let chatSessionID, _, let title):
            mhbTempFrontendLog(
                "stage=store.handle.message_started chat_session_id=\(chatSessionID) title_len=\(title.count) before_session=\(currentChatSessionID ?? "nil")"
            )
            currentChatSessionID = chatSessionID.uuidString
            if !title.isEmpty && title != "新对话" {
                currentConversationTitle = title
            } else if currentConversationTitle == nil {
                currentConversationTitle = title
            }
            ensureStreamingPlaceholderExists()

        case .agentActivity(let displayText, let status):
            applyAgentActivity(displayText: displayText, status: status)

        case .confirmationTask(let taskID, let questionText):
            pendingConfirmationTask = PendingConfirmationTask(
                id: taskID.uuidString,
                questionText: questionText
            )

        case .delta(let text):
            mhbTempFrontendLog(
                "stage=store.handle.delta chars=\(text.count) trimmed_empty=\(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) active_id=\(String(describing: streamingEngine.activeMessageID))"
            )
            clearActiveAgentActivity()
            streamingEngine.appendDelta(text)
            streamingEngine.flush()
            streamingRevision += 1

        case .citation(let label):
            appendPendingReferenceChip(label)

        case .messageCompleted(let messageID, let finalText, let chips):
            mhbTempFrontendLog(
                "stage=store.handle.completed message_id=\(messageID) final_chars=\(finalText.count) final_trimmed_empty=\(finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) chips=\(chips.count) active_id=\(String(describing: streamingEngine.activeMessageID))"
            )
            clearActiveAgentActivity()
            let resolvedChips = chips.isEmpty ? pendingReferenceChips : chips
            applyCompletedAssistantMessage(finalText: finalText, referenceChips: resolvedChips)
            markAssistantReplyCompletedIfVisible(finalText)
            pendingReferenceChips = []

        case .proposedAction(let action):
            pendingAction = AIAssistantProposedAction(from: action)

        case .error(let code, _, let retryable, let safeFallbackText):
            mhbTempFrontendLog(
                "stage=store.handle.error code=\(code) retryable=\(retryable) safe_present=\(safeFallbackText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) active_id=\(String(describing: streamingEngine.activeMessageID)) streaming_placeholders=\(messages.filter(\.isStreaming).count)"
            )
            clearActiveAgentActivity()
            pendingReferenceChips = []
            recordStreamIssue(
                source: "backend_sse_error",
                code: code,
                retryable: retryable,
                hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
            )
            finishBackendError(safeFallbackText: safeFallbackText)
            markAssistantReplyCompletedIfVisible(safeFallbackText ?? "")
        }
    }

    func applyAgentActivity(displayText: String, status: String) {
        guard status == "started" else {
            clearActiveAgentActivity()
            return
        }
        let trimmedText = displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else { return }
        activeAgentActivityText = trimmedText
        streamingRevision += 1
    }

    func clearActiveAgentActivity() {
        guard activeAgentActivityText != nil else { return }
        activeAgentActivityText = nil
        streamingRevision += 1
    }

    func appendPendingReferenceChip(_ label: String) {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLabel.isEmpty == false else { return }
        guard pendingReferenceChips.contains(trimmedLabel) == false else { return }
        pendingReferenceChips.append(trimmedLabel)
    }

    func ensureStreamingPlaceholderExists() {
        guard streamingEngine.activeMessageID == nil else { return }
        let placeholder = AIAssistantMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(placeholder)
        mhbTempFrontendLog(
            "stage=store.placeholder.ensure_new placeholder_id=\(placeholder.id) message_count=\(messages.count)"
        )
        beginStreaming(messageID: placeholder.id)
        streamingRevision += 1
    }

    func applyCompletedAssistantMessage(finalText: String, referenceChips: [String]) {
        let activeMessageID = streamingEngine.activeMessageID
        mhbTempFrontendLog(
            "stage=store.apply_completed.start active_id=\(String(describing: activeMessageID)) final_chars=\(finalText.count) final_trimmed_empty=\(finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) chips=\(referenceChips.count)"
        )
        if let activeMessageID {
            completeStreaming(finalText: finalText)
            if let index = messages.firstIndex(where: { $0.id == activeMessageID }) {
                messages[index].referenceChips = referenceChips
            }
            streamingRevision += 1
            return
        }

        cancelStreaming()
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
    }

    func markAssistantReplyCompletedIfVisible(_ text: String) {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        assistantReplyCompletionSequence += 1
    }

    func handleStreamError(_ error: Error) {
        if error is CancellationError { return }
        pendingReferenceChips = []
        mhbTempFrontendLog(
            "stage=store.local_error error_code=\(streamErrorDiagnosticsCode(error)) streaming_placeholders=\(messages.filter(\.isStreaming).count)"
        )
        recordStreamIssue(
            source: "local_stream_error",
            code: streamErrorDiagnosticsCode(error),
            hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
        )
        replaceStreamingOrAppendAssistantMessage(Self.networkFailureFallbackText)
    }

    func finishBackendError(safeFallbackText: String?) {
        let trimmedText = safeFallbackText?.trimmingCharacters(in: .whitespacesAndNewlines)
        mhbTempFrontendLog(
            "stage=store.finish_backend_error safe_present=\(trimmedText?.isEmpty == false) active_id=\(String(describing: streamingEngine.activeMessageID))"
        )
        guard let trimmedText, trimmedText.isEmpty == false else {
            discardCurrentAssistantReply()
            return
        }
        replaceStreamingOrAppendAssistantMessage(trimmedText)
    }

    func replaceStreamingOrAppendAssistantMessage(_ text: String) {
        mhbTempFrontendLog(
            "stage=store.replace_or_append.start text_chars=\(text.count) trimmed_empty=\(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) streaming_placeholders=\(messages.filter(\.isStreaming).count) active_id=\(String(describing: streamingEngine.activeMessageID))"
        )
        cancelStreaming()
        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            mhbTempFrontendLog(
                "stage=store.replace_or_append.replace index=\(index)"
            )
            messages[index].text = text
            messages[index].isStreaming = false
        } else {
            mhbTempFrontendLog("stage=store.replace_or_append.append")
            messages.append(AIAssistantMessage(role: .assistant, text: text))
        }
        streamingRevision += 1
    }

    func finishStreamIfAssistantReplyMissing(
        after startIndex: Int,
        placeholderID: UUID? = nil,
        didReceiveAssistantReply: Bool = false
    ) {
        mhbTempFrontendLog(
            "stage=store.finish_missing.check start_index=\(startIndex) placeholder_id=\(String(describing: placeholderID)) did_receive=\(didReceiveAssistantReply) has_completed_placeholder=\(placeholderID.map { hasCompletedAssistantReply(messageID: $0) } ?? false) has_completed_after=\(hasCompletedAssistantReply(after: startIndex))"
        )
        if let placeholderID, hasCompletedAssistantReply(messageID: placeholderID) {
            return
        }
        if didReceiveAssistantReply {
            return
        }
        guard hasCompletedAssistantReply(after: startIndex) == false else { return }
        pendingReferenceChips = []
        recordStreamIssue(
            source: "local_empty_stream",
            code: "ai.empty_stream",
            hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
        )
        discardIncompleteAssistantReplies(after: startIndex)
    }

    func streamEventCompletesAssistantReply(_ event: AIStreamEventDTO) -> Bool {
        switch event {
        case .messageCompleted(_, let finalText, _):
            return finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .error(_, _, _, let safeFallbackText):
            return safeFallbackText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .messageStarted,
             .agentActivity,
             .confirmationTask,
             .delta,
             .citation,
             .proposedAction:
            return false
        }
    }

    func hasCompletedAssistantReply(messageID: UUID) -> Bool {
        messages.contains { message in
            message.id == messageID
                && message.role == .assistant
                && message.isStreaming == false
                && message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    func hasCompletedAssistantReply(after startIndex: Int) -> Bool {
        messages.enumerated().contains { index, message in
            index >= startIndex
                && message.role == .assistant
                && message.isStreaming == false
                && message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    func discardIncompleteAssistantReplies(after startIndex: Int) {
        let hadActiveStream = isStreaming
        cancelStreaming()
        let originalCount = messages.count
        mhbTempFrontendLog(
            "stage=store.discard_incomplete.start start_index=\(startIndex) original_count=\(originalCount) had_active_stream=\(hadActiveStream)"
        )
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
    }

    func discardCurrentAssistantReply() {
        let activeMessageID = streamingEngine.activeMessageID
        let hadActiveStream = isStreaming
        mhbTempFrontendLog(
            "stage=store.discard_current.start active_id=\(String(describing: activeMessageID)) had_active_stream=\(hadActiveStream) message_count=\(messages.count)"
        )
        cancelStreaming()
        let originalCount = messages.count
        if let activeMessageID {
            messages.removeAll { $0.id == activeMessageID }
        } else {
            messages.removeAll { $0.isStreaming }
        }
        if hadActiveStream || messages.count != originalCount {
            streamingRevision += 1
        }
    }

    func recordStreamIssue(
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

    func streamErrorDiagnosticsCode(_ error: Error) -> String {
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

    func makeConversationTitle(from text: String) -> String {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > 18 else { return title }
        return "\(title.prefix(18))..."
    }

    func updateHistory(
        _ id: String,
        transform: (AIAssistantConversationHistory) -> AIAssistantConversationHistory
    ) {
        guard let index = histories.firstIndex(where: { $0.id == id }) else { return }
        histories[index] = transform(histories[index])
    }

    func sortHistoriesByPinnedState() {
        let pinned = histories.filter(\.isPinned)
        let unpinned = histories.filter { !$0.isPinned }
        histories = pinned + unpinned
    }

    func loadSessionMessages(sessionID: String) async {
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
            return
        }
    }
}

// MHB_TEMP_FRONTEND_LOG: AgentFallbackRegression 临时前端日志，确认修复后删除。
private func mhbTempFrontendLog(_ message: String) {
    print("[DEBUG:AgentFallbackRegression] \(message)")
}
