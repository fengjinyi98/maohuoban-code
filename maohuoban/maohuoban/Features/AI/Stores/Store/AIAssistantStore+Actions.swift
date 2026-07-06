import Foundation
import UIKit

extension AIAssistantStore {
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

    func confirmPendingConfirmationTask() {
        guard let task = pendingConfirmationTask else { return }
        pendingConfirmationTask = nil
        runConfirmationTaskStream(
            taskID: task.id,
            userVisibleText: task.approveLabel
        )
    }

    func rejectPendingConfirmationTask() {
        guard let pendingConfirmationTask else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.repository.rejectConfirmationTask(taskID: pendingConfirmationTask.id)
                self.pendingConfirmationTask = nil
                self.messages.append(AIAssistantMessage(role: .assistant, text: "已取消这条记录。"))
            } catch {
                self.messages.append(
                    AIAssistantMessage(
                        role: .assistant,
                        text: "取消失败，请稍后重试。",
                        referenceChips: ["确认任务未关闭"]
                    )
                )
            }
        }
    }

    func confirm(_ action: AIAssistantProposedAction) async {
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

    private func runConfirmationTaskStream(taskID: String, userVisibleText: String) {
        messages.append(AIAssistantMessage(role: .user, text: userVisibleText, createdAt: Date()))
        let assistantReplyStartIndex = messages.count
        let placeholder = AIAssistantMessage(role: .assistant, text: "", createdAt: Date(), isStreaming: true)
        messages.append(placeholder)
        pendingReferenceChips = []
        pendingReferences = []
        beginStreaming(messageID: placeholder.id)

        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }
            let completionSequenceBeforeStream = self.assistantReplyCompletionSequence
            var didReceiveAssistantReply = false
            let stream = self.repository.openChatStream(
                message: userVisibleText,
                selectedPetID: self.effectiveEntryContext.selectedPetID,
                surface: "home_private",
                chatSessionID: self.currentChatSessionID,
                entryContext: self.effectiveEntryContext,
                confirmationTaskID: taskID
            )
            do {
                for try await event in stream {
                    if Task.isCancelled { return }
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
                self.handleStreamError(error)
            }
        }
    }
}

private extension PendingConfirmationTask {
    var approveLabel: String {
        actions.first { $0.kind == "approve" }?.label ?? "确认写入"
    }
}
