import SwiftUI
import MaohuobanDesignSystem

// AIAssistantContextHeader AI 助手上下文头部
// 核心职责：
// - 展示当前私域宠物上下文
// - 承载 UGC 交接内容的前端展示入口
struct AIAssistantContextHeader: View {
    let context: AIAssistantEntryContext

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "sparkles")
                    .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: 42, height: 42)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text("私域宠物助手")
                        .font(MHBTheme.Typography.title)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text("当前宠物：\(context.displayPetName)")
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
            }

            if let ugcContextTitle = context.ugcContextTitle {
                AIAssistantContextChip(
                    systemImage: "doc.text.magnifyingglass",
                    text: "已带入：\(ugcContextTitle)"
                )
            }

            HStack(spacing: MHBTheme.Spacing.s2) {
                AIAssistantContextChip(systemImage: "lock.shield.fill", text: "私域授权")
                AIAssistantContextChip(systemImage: "checkmark.seal.fill", text: "写入需确认")
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
        .accessibilityIdentifier("ai.assistant.contextHeader")
    }
}

// AIAssistantContextChip AI 助手上下文标签
// 核心职责：
// - 用紧凑标签表达当前会话的权限和来源
// - 保持头部信息可快速扫描
private struct AIAssistantContextChip: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(MHBTheme.Typography.caption)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .lineLimit(1)
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .frame(height: MHBTheme.Spacing.s8)
            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
            .clipShape(Capsule())
    }
}
