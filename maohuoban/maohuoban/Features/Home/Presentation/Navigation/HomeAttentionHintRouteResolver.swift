import Foundation

// HomeAttentionHintRouteResolver 首页轻提示路由解析器
// 核心职责：
// - 将轻提示动作映射为首页 Tab 内导航目标
// - 保留异常追踪进入 AI 会话所需的宠物和异常上下文
enum HomeAttentionHintRouteResolver {
    static func route(
        for action: AttentionHintAction,
        hint: HomeDashboardSnapshot.AttentionHint,
        petName: String?,
        recordContext: PetRecordEntryContext
    ) -> HomeRoute {
        switch action.routeKind {
        case .abnormalDetail:
            return abnormalDetailRoute(
                hint: hint,
                recordContext: recordContext,
                opensFollowupSheet: action.presentation?.autoOpenSheet == "abnormal_followup"
            )
        case .aiChat:
            return aiChatRoute(
                hint: hint,
                chatContext: action.chatContext,
                petName: petName,
                recordContext: recordContext
            )
        case .weightRecord:
            return weightRoute(hint: hint, recordContext: recordContext)
        case .reminderDetail, .preventiveCareDetail, .confirmationTask:
            return unsupportedRoute(hint: hint)
        }
    }

    private static func abnormalDetailRoute(
        hint: HomeDashboardSnapshot.AttentionHint,
        recordContext: PetRecordEntryContext,
        opensFollowupSheet: Bool
    ) -> HomeRoute {
        let payload = hint.route.payload
        let recordID = payload?.recordID
            ?? hint.sourceRefID
            ?? hint.id
        let eventID = payload?.eventID ?? recordID
        return .petRecordDetail(.abnormal(
            recordID: eventID,
            context: recordContext,
            opensFollowupSheet: opensFollowupSheet
        ))
    }

    private static func aiChatRoute(
        hint: HomeDashboardSnapshot.AttentionHint,
        chatContext: AttentionHintChatContext?,
        petName: String?,
        recordContext: PetRecordEntryContext
    ) -> HomeRoute {
        HomeRoute.petAssistant(AIAssistantEntryContext(
            selectedPetID: recordContext.resolvedPetID,
            selectedPetName: petName ?? recordContext.resolvedPetName,
            selectedPetAvatarURL: recordContext.petAvatarURL ?? recordContext.selectedSwitchPet?.avatarURL,
            selectedPetSpecies: recordContext.selectedSwitchPet?.species.aiAssistantSpecies ?? .other,
            abnormalEpisodeID: chatContext?.episodeID ?? hint.route.payload?.episodeID,
            abnormalEventID: hint.route.payload?.eventID ?? hint.route.payload?.recordID ?? hint.sourceRefID,
            sourceHintID: chatContext?.sourceHintID ?? hint.id,
            agentFollowupID: chatContext?.agentFollowupID ?? hint.route.payload?.agentFollowupID
        ))
    }

    private static func weightRoute(
        hint: HomeDashboardSnapshot.AttentionHint,
        recordContext: PetRecordEntryContext
    ) -> HomeRoute {
        let recordID = hint.route.payload?.recordID ?? hint.sourceRefID ?? hint.id
        return .petWeightRecordDetail(recordID: recordID, context: recordContext)
    }

    private static func unsupportedRoute(hint: HomeDashboardSnapshot.AttentionHint) -> HomeRoute {
        let recordID = hint.route.payload?.recordID ?? hint.sourceRefID ?? hint.id
        return .petRecordDetail(.unsupported(recordID: recordID))
    }
}

private extension PetRecordPetSpecies {
    var aiAssistantSpecies: AIAssistantPetSpecies {
        switch self {
        case .dog:
            .dog
        case .cat:
            .cat
        case .other:
            .other
        }
    }
}
