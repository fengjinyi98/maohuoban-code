import Foundation

extension AIAssistantProposedAction {
    init(from dto: AIProposedActionDTO) {
        self.init(
            id: dto.id.uuidString,
            actionKind: dto.actionKind,
            targetPetID: dto.targetPetID.uuidString,
            title: Self.titleText(for: dto.actionKind),
            subtitle: dto.confirmText,
            confirmTitle: dto.confirmText,
            cancelTitle: "暂不确认",
            systemImage: Self.systemImage(for: dto.actionKind),
            payload: dto.payload.map { payload in
                AIAssistantProposedActionPayload(
                    foodItemID: payload.foodItemID?.uuidString,
                    confirmedFactKind: payload.confirmedFactKind,
                    sourceQuestion: payload.sourceQuestion,
                    deriveDietChange: payload.deriveDietChange,
                    deriveFeedingCorrection: payload.deriveFeedingCorrection
                )
            }
        )
    }

    private static func titleText(for actionKind: String) -> String {
        switch actionKind {
        case "diet_change_confirmation": "确认换粮"
        case "feeding_correction": "修正喂食"
        case "symptom_followup": "记录症状"
        case "reminder_creation": "添加提醒"
        case "risk_context_confirmation": "确认风险"
        default: "确认动作"
        }
    }

    private static func systemImage(for actionKind: String) -> String {
        switch actionKind {
        case "diet_change_confirmation": "fork.knife"
        case "feeding_correction": "pencil.line"
        case "symptom_followup": "waveform.path.ecg"
        case "reminder_creation": "calendar.badge.plus"
        case "risk_context_confirmation": "exclamationmark.shield"
        default: "checkmark.circle"
        }
    }
}
