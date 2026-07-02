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
}
