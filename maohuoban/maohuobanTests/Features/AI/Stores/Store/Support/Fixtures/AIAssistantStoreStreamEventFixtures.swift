import Foundation
@testable import maohuoban

extension AIAssistantStoreStreamEventTests {
    static func fullFlowEvents() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "腹泻观察"),
            .delta(text: "需要观察"),
            .delta(text: "精神状态和食欲"),
            .messageCompleted(
                messageID: messageID,
                finalText: "需要观察精神状态和食欲",
                referenceChips: ["健康分级", "红旗症状"],
                references: []
            ),
        ]
    }

    static func errorEvents() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "新对话"),
            .error(
                code: "ai.provider_not_configured",
                message: "AI 服务未配置",
                retryable: false,
                safeFallbackText: "AI 服务暂时不可用，请稍后重试。"
            ),
        ]
    }

    static func errorEventsWithoutSafeText() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "新对话"),
            .error(
                code: "ai.provider_not_configured",
                message: "AI 服务未配置",
                retryable: false,
                safeFallbackText: nil
            ),
        ]
    }

    static func backendCompletionOnlyEvents() -> [AIStreamEventDTO] {
        [
            .messageCompleted(
                messageID: UUID(),
                finalText: "我现在只能处理宠物照护、宠物记录和毛伙伴 App 相关问题。",
                referenceChips: [],
                references: []
            ),
        ]
    }

    static func startedOnlyEvents() -> [AIStreamEventDTO] {
        [
            .messageStarted(chatSessionID: UUID(), messageID: UUID(), title: "新对话"),
        ]
    }

    static func streamWithAction() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        let actionID = UUID()
        let petID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "疫苗咨询"),
            .delta(text: "建议确认换粮"),
            .messageCompleted(
                messageID: messageID,
                finalText: "建议确认换粮",
                referenceChips: ["饮食记录"],
                references: []
            ),
            .proposedAction(action: AIProposedActionDTO(
                id: actionID,
                actionKind: "diet_change_confirmation",
                targetPetID: petID,
                confirmText: "确认换粮",
                riskLevel: "low",
                payload: AIProposedActionPayloadDTO(
                    foodItemID: UUID(),
                    confirmedFactKind: "diet_change",
                    sourceQuestion: "是否确认换粮？",
                    deriveDietChange: true,
                    deriveFeedingCorrection: false
                )
            )),
        ]
    }

    static func titleEvents() -> [AIStreamEventDTO] {
        let sessionID = UUID()
        let messageID = UUID()
        return [
            .messageStarted(chatSessionID: sessionID, messageID: messageID, title: "疫苗咨询"),
            .messageCompleted(
                messageID: messageID,
                finalText: "ok",
                referenceChips: [],
                references: []
            ),
        ]
    }
}
