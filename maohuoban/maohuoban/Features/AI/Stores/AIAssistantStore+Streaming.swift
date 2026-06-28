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
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].text = text
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            messages[index].activityText = nil
        }
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
        beginStreaming(messageID: placeholder.id)

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
                self.finishStreamIfAssistantReplyMissing(after: assistantReplyStartIndex)
            } catch {
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
            currentChatSessionID = chatSessionID.uuidString
            if !title.isEmpty && title != "新对话" {
                currentConversationTitle = title
            } else if currentConversationTitle == nil {
                currentConversationTitle = title
            }
            ensureStreamingPlaceholderExists()

        case .toolCall(let toolName, let status, let citationCount):
            activeToolStatus = ActiveToolStatus(
                toolName: toolName,
                status: status,
                citationCount: citationCount
            )

        case .agentActivity(let displayText, let status):
            applyAgentActivity(displayText: displayText, status: status)

        case .confirmationTask(let taskID, let questionText):
            pendingConfirmationTask = PendingConfirmationTask(
                id: taskID.uuidString,
                questionText: questionText
            )

        case .delta(let text):
            clearActiveAgentActivity()
            streamingEngine.appendDelta(text)
            streamingEngine.flush()
            streamingRevision += 1

        case .messageCompleted(_, let finalText, let chips):
            clearActiveAgentActivity()
            applyCompletedAssistantMessage(finalText: finalText, referenceChips: chips)

        case .proposedAction(let action):
            pendingAction = AIAssistantProposedAction(from: action)

        case .error(let code, _, let retryable, let safeFallbackText):
            clearActiveAgentActivity()
            recordStreamIssue(
                source: "backend_sse_error",
                code: code,
                retryable: retryable,
                hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
            )
            finishBackendError(safeFallbackText: safeFallbackText)
        }
    }

    func applyAgentActivity(displayText: String, status: String) {
        guard status == "started" else {
            clearActiveAgentActivity()
            return
        }
        let trimmedText = displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else { return }

        if let activeMessageID = streamingEngine.activeMessageID,
           let index = messages.firstIndex(where: { $0.id == activeMessageID }) {
            messages[index].activityText = trimmedText
            streamingRevision += 1
        }
    }

    func clearActiveAgentActivity() {
        let activeMessageID = streamingEngine.activeMessageID
        let index: Int?
        if let activeMessageID {
            index = messages.firstIndex(where: { $0.id == activeMessageID })
        } else {
            index = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming })
        }

        guard let index, messages[index].activityText != nil else { return }
        messages[index].activityText = nil
        streamingRevision += 1
    }

    func ensureStreamingPlaceholderExists() {
        guard streamingEngine.activeMessageID == nil else { return }
        let placeholder = AIAssistantMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(placeholder)
        beginStreaming(messageID: placeholder.id)
        streamingRevision += 1
    }

    func applyCompletedAssistantMessage(finalText: String, referenceChips: [String]) {
        let activeMessageID = streamingEngine.activeMessageID
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

    func handleStreamError(_ error: Error) {
        if error is CancellationError { return }
        recordStreamIssue(
            source: "local_stream_error",
            code: streamErrorDiagnosticsCode(error),
            hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
        )
        replaceStreamingOrAppendAssistantMessage(Self.networkFailureFallbackText)
    }

    func finishBackendError(safeFallbackText: String?) {
        let trimmedText = safeFallbackText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedText, trimmedText.isEmpty == false else {
            discardCurrentAssistantReply()
            return
        }
        replaceStreamingOrAppendAssistantMessage(trimmedText)
    }

    func replaceStreamingOrAppendAssistantMessage(_ text: String) {
        cancelStreaming()
        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            messages[index].text = text
            messages[index].isStreaming = false
        } else {
            messages.append(AIAssistantMessage(role: .assistant, text: text))
        }
        streamingRevision += 1
    }

    func finishStreamIfAssistantReplyMissing(after startIndex: Int) {
        guard hasCompletedAssistantReply(after: startIndex) == false else { return }
        recordStreamIssue(
            source: "local_empty_stream",
            code: "ai.empty_stream",
            hasStreamingPlaceholder: messages.contains(where: \.isStreaming)
        )
        discardIncompleteAssistantReplies(after: startIndex)
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
