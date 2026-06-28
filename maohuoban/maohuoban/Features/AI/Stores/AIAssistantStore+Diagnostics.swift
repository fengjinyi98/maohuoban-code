import Foundation

extension AIAssistantStore {
    func streamEventDebugName(_ event: AIStreamEventDTO) -> String {
        switch event {
        case .messageStarted:
            "message_started"
        case .toolCall:
            "tool_call"
        case .agentActivity:
            "agent_activity"
        case .confirmationTask:
            "confirmation_task"
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

    #if DEBUG
    func triggerMockStreamingResponse() {
        startMockStreamingResponse(
            fullText: AIAssistantMockContent.longStreamingText,
            referenceChips: ["意图识别", "受控工具", "来源校验"],
            action: nil
        )
    }

    func startMockStreamingResponse(
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

    func splitIntoChunks(_ text: String) -> [String] {
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
    #endif
}
