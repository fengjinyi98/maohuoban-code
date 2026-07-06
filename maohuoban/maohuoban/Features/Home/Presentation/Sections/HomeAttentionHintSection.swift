import SwiftUI
import MaohuobanDesignSystem

// HomeAttentionHintSection 首页通用轻提示
// 核心职责：
// - 在时间线上方展示后端返回的 active attention_hints
// - 不使用背景、描边或卡片容器，只通过图标颜色表达提醒
// - 点击后按 route_kind 路由到对应详情页
// 边界：attention_hints 是待处理信号，不是事实账本；与 Reminder 独立
struct HomeAttentionHintSection: View {
    let hints: [HomeDashboardSnapshot.AttentionHint]
    let petName: String?
    let recordContext: PetRecordEntryContext
    let onOpenRoute: (HomeRoute) -> Void

    var body: some View {
        if let topHint = hints.first {
            HomeAttentionHintRow(
                hint: topHint,
                petName: petName,
                recordContext: recordContext,
                onOpenRoute: onOpenRoute
            )
        }
    }
}

// HomeAttentionHintRow 单条轻提示行
// 核心职责：
// - 展示一条 attention_hint 的图标、标题和查看入口
// - 点击后通过 NavigationLink 路由到对应详情页
private struct HomeAttentionHintRow: View {
    let hint: HomeDashboardSnapshot.AttentionHint
    let petName: String?
    let recordContext: PetRecordEntryContext
    let onOpenRoute: (HomeRoute) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: iconSystemName)
                .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                .foregroundStyle(tintColor)
                .frame(width: 28, height: 28)
                .padding(.top, MHBTheme.Spacing.s1)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(displayTitle)
                    .font(MHBTheme.Typography.callout.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                HomeAttentionHintActionRow(
                    actions: displayActions,
                    onSelect: { action in
                        onOpenRoute(route(for: action))
                    }
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityIdentifier("home.attentionHint")
    }

    private var displayTitle: String {
        if hint.subtitle.isEmpty {
            return hint.title
        }
        return "\(hint.title) · \(hint.subtitle)"
    }

    private var iconSystemName: String {
        switch hint.kind {
        case .openAbnormalEpisode, .abnormalFollowupDue:
            "cross.case.fill"
        case .dietChangeConfirmation:
            "fork.knife.circle.fill"
        case .preventiveCareDue:
            "syringe.fill"
        case .reminderDue:
            "bell.badge.fill"
        case .weightStale:
            "scalemass.fill"
        case .feedingPatternChanged:
            "calendar.badge.clock"
        }
    }

    private var tintColor: Color {
        switch hint.tone {
        case .info:
            MHBTheme.ColorToken.primary.color
        case .notice:
            MHBTheme.ColorToken.warning.color
        case .warning:
            MHBTheme.ColorToken.warning.color
        case .critical:
            MHBTheme.ColorToken.danger.color
        }
    }

    private var displayActions: [AttentionHintAction] {
        if !hintActions.isEmpty {
            return hintActions
        }
        return [
            AttentionHintAction(
                id: "view_detail",
                title: "查看",
                routeKind: hint.route.kind,
                presentation: nil,
                chatContext: nil
            )
        ]
    }

    private var hintActions: [AttentionHintAction] {
        hint.route.payload?.actions ?? []
    }

    private func route(for action: AttentionHintAction) -> HomeRoute {
        switch action.routeKind {
        case .abnormalDetail:
            abnormalDetailRoute(
                opensFollowupSheet: action.presentation?.autoOpenSheet == "abnormal_followup"
            )
        case .aiChat:
            aiChatRoute(chatContext: action.chatContext)
        case .weightRecord:
            weightRoute()
        case .reminderDetail, .preventiveCareDetail, .confirmationTask:
            unsupportedRoute()
        }
    }

    private func abnormalDetailRoute(opensFollowupSheet: Bool) -> HomeRoute {
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

    private func aiChatRoute(chatContext: AttentionHintChatContext?) -> HomeRoute {
        HomeRoute.petAssistant(AIAssistantEntryContext(
            selectedPetID: recordContext.resolvedPetID,
            selectedPetName: petName ?? recordContext.resolvedPetName,
            abnormalEpisodeID: chatContext?.episodeID ?? hint.route.payload?.episodeID,
            sourceHintID: chatContext?.sourceHintID ?? hint.id,
            agentFollowupID: chatContext?.agentFollowupID ?? hint.route.payload?.agentFollowupID
        ))
    }

    private func weightRoute() -> HomeRoute {
        let recordID = hint.route.payload?.recordID ?? hint.sourceRefID ?? hint.id
        return .petWeightRecordDetail(recordID: recordID, context: recordContext)
    }

    private func unsupportedRoute() -> HomeRoute {
        let recordID = hint.route.payload?.recordID ?? hint.sourceRefID ?? hint.id
        return .petRecordDetail(.unsupported(recordID: recordID))
    }
}

// HomeAttentionHintActionRow 轻提示文字动作区
// 核心职责：
// - 以文字按钮展示后端下发的轻提醒动作
// - 保持首页轻提示 UI 轻量，不增加边框和嵌套卡片
private struct HomeAttentionHintActionRow: View {
    let actions: [AttentionHintAction]
    let onSelect: (AttentionHintAction) -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            ForEach(Array(actions.prefix(2).enumerated()), id: \.element.id) { index, action in
                Button {
                    onSelect(action)
                } label: {
                    Text(action.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(actionColor(index: index))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionColor(index: Int) -> Color {
        index == 0
            ? MHBTheme.ColorToken.primary.color
            : MHBTheme.ColorToken.labelSecondary.color
    }
}
