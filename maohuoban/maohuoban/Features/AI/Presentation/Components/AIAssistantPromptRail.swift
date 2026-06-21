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
                        AIAssistantPromptChip(prompt: prompt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ai.assistant.prompt.\(prompt.id)")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
        }
        .padding(.horizontal, -MHBTheme.Spacing.s4)
        .accessibilityIdentifier("ai.assistant.promptRail")
    }
}

// AIAssistantPromptChip AI 助手建议问题标签
// 核心职责：
// - 渲染单个建议问题入口
// - 使用稳定尺寸避免横滑布局跳动
private struct AIAssistantPromptChip: View {
    let prompt: AIAssistantSuggestedPrompt

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: prompt.systemImage)
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))

            Text(prompt.title)
                .font(MHBTheme.Typography.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .frame(height: 40)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}
