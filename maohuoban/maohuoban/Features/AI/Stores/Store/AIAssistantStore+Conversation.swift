import Foundation

extension AIAssistantStore {
    func selectConversationHistory(_ history: AIAssistantConversationHistory) {
        selectedConversationHistoryID = history.id
        currentConversationTitle = history.title
        currentChatSessionID = history.id
        draftText = ""
        pendingAction = nil
        activeAgentActivityText = nil
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
        activeAgentActivityText = nil
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
        }
    }
}
