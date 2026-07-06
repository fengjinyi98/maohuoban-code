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

    func restoreAbnormalEpisodeConversationIfNeeded() async {
        guard let abnormalEpisodeID = context.abnormalEpisodeID,
              currentChatSessionID == nil
        else {
            return
        }

        do {
            let activationResponse = try await repository.activateAbnormalEpisodeSession(
                abnormalEpisodeID: abnormalEpisodeID
            )
            let response = try await repository.fetchChatSessions()
            guard let sessions = response.data else {
                if let session = activationResponse.data {
                    await restoreAbnormalEpisodeConversation(
                        from: session,
                        abnormalEpisodeID: abnormalEpisodeID
                    )
                }
                return
            }
            histories = sessions.map { AIAssistantConversationHistory(from: $0) }
            guard let session = sessions.first(where: { dto in
                dto.chatContextKind == "abnormal_episode_followup"
                    && dto.abnormalEpisodeID == abnormalEpisodeID
            }) else {
                if let session = activationResponse.data {
                    await restoreAbnormalEpisodeConversation(
                        from: session,
                        abnormalEpisodeID: abnormalEpisodeID
                    )
                }
                return
            }

            await restoreAbnormalEpisodeConversation(
                from: session,
                abnormalEpisodeID: abnormalEpisodeID
            )
        } catch {
            return
        }
    }

    private func restoreAbnormalEpisodeConversation(
        from session: AIChatSessionDTO,
        abnormalEpisodeID: String
    ) async {
        let sessionID = session.id.uuidString
        selectedConversationHistoryID = sessionID
        currentConversationTitle = session.title
        currentChatSessionID = sessionID
        effectiveEntryContext = AIAssistantEntryContext(
            selectedPetID: context.selectedPetID,
            selectedPetName: context.selectedPetName,
            selectedPetAvatarURL: context.selectedPetAvatarURL,
            selectedPetSpecies: context.selectedPetSpecies,
            ugcContextTitle: context.ugcContextTitle,
            abnormalEpisodeID: session.abnormalEpisodeID ?? abnormalEpisodeID,
            abnormalEventID: context.abnormalEventID,
            sourceHintID: session.sourceHintID,
            agentFollowupID: session.agentFollowupID
        )
        draftText = ""
        pendingAction = nil
        activeAgentActivityText = nil
        clearAttachment()
        await loadSessionMessages(sessionID: sessionID)
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
                messages = data.compactMap { dto in
                    guard let role = AIAssistantMessage.Role(userVisibleRole: dto.role) else {
                        return nil
                    }
                    return AIAssistantMessage(
                        role: role,
                        text: dto.content,
                        referenceChips: dto.citations.map(\.label),
                        references: dto.citations.map(\.reference),
                        contentBlocks: dto.contentBlocks,
                        createdAt: MHBUTCDateDisplayFormatter.date(fromUTCString: dto.createdAt)
                    )
                }
            }
        } catch {
            return
        }
    }
}
