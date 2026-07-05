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

    var body: some View {
        if let topHint = hints.first {
            HomeAttentionHintRow(
                hint: topHint,
                petName: petName,
                recordContext: recordContext
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

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: iconSystemName)
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(tintColor)
                    .frame(width: 28, height: 28)

                HomeAttentionHintMarqueeText(text: displayTitle)

                Spacer(minLength: MHBTheme.Spacing.s3)

                HStack(spacing: MHBTheme.Spacing.s1) {
                    Text("查看")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            "takeoutbag.and.cup.and.straw.fill"
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

    private var route: HomeRoute {
        let payload = hint.route.payload
        let recordID = payload?.recordID
            ?? hint.sourceRefID
            ?? hint.id

        switch hint.route.kind {
        case .abnormalDetail:
            return .petRecordDetail(.abnormal(recordID: recordID, context: recordContext))
        case .weightRecord:
            return .petWeightRecordDetail(recordID: recordID, context: recordContext)
        case .reminderDetail:
            return .petRecordDetail(.unsupported(recordID: recordID))
        case .preventiveCareDetail:
            return .petRecordDetail(.unsupported(recordID: recordID))
        case .confirmationTask:
            return .petRecordDetail(.unsupported(recordID: recordID))
        case .aiChat:
            return .petRecordDetail(.unsupported(recordID: recordID))
        case .pantryItemDetail:
            return .pantryItemDetail(
                context: PetPantryEntryContext(
                    sourcePetID: recordContext.petID,
                    sourcePetName: recordContext.petName
                ),
                itemID: payload?.foodItemID ?? recordID,
                promptKind: payload?.inventoryPromptKind
            )
        }
    }
}
