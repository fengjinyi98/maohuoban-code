import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPromptRail AI 助手建议问题横栏
// 核心职责：
// - 展示首屏可直接发送的问题入口
// - 将用户选择转发给上层 Store
struct AIAssistantPromptRail: View {
    let prompts: [AIAssistantSuggestedPrompt]
    let onSelect: (AIAssistantSuggestedPrompt) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                ForEach(prompts) { prompt in
                    Button {
                        onSelect(prompt)
                    } label: {
                        AIAssistantPromptCard(prompt: prompt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ai.assistant.prompt.\(prompt.id)")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.vertical, MHBTheme.Spacing.s1)
        }
        .accessibilityIdentifier("ai.assistant.promptRail")
    }
}

// AIAssistantPromptCard AI 助手建议问题卡片
// 核心职责：
// - 渲染单个建议问题入口
// - 使用稳定尺寸贴近底部输入区建议布局
private struct AIAssistantPromptCard: View {
    let prompt: AIAssistantSuggestedPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(prompt.title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            Text(prompt.subtitle)
                .font(MHBTheme.Typography.body)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(width: 142, height: 76, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}
