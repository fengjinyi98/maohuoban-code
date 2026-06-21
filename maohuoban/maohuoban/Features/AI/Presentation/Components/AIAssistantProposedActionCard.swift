import SwiftUI
import MaohuobanDesignSystem

// AIAssistantProposedActionCard AI 建议动作确认卡
// 核心职责：
// - 展示 AI 生成但尚未执行的写操作意图
// - 要求用户显式确认或取消
struct AIAssistantProposedActionCard: View {
    let action: AIAssistantProposedAction
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                Image(systemName: action.systemImage)
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.warning.color)
                    .frame(width: 36, height: 36)
                    .background(MHBTheme.ColorToken.warning.color.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(action.title)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(action.subtitle)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ViewThatFits {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    actionButtons
                }

                VStack(spacing: MHBTheme.Spacing.s3) {
                    actionButtons
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.warning.color.opacity(0.26), lineWidth: 1)
        }
        .accessibilityIdentifier("ai.assistant.proposedAction")
    }

    private var actionButtons: some View {
        Group {
            Button(action: onCancel) {
                Text(action.cancelTitle)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
            .clipShape(Capsule())

            Button(action: onConfirm) {
                Text(action.confirmTitle)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(MHBTheme.ColorToken.primary.color)
            .clipShape(Capsule())
        }
    }
}
