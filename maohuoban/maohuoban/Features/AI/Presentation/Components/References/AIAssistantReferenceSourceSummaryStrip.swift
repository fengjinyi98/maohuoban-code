import SwiftUI
import MaohuobanDesignSystem

// AIAssistantReferenceSourceSummaryStrip AI 引用来源摘要入口
// 核心职责：
// - 在回复底部展示后端来源类型摘要
// - 用图标帮助用户快速识别引用来源
struct AIAssistantReferenceSourceSummaryStrip: View {
    let summaries: [AIAssistantReferenceSourceSummary]

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(summaries) { summary in
                HStack(spacing: MHBTheme.Spacing.s1) {
                    Image(systemName: summary.systemImage)
                        .font(.system(size: 12, weight: .semibold))

                    Text(summary.displayText)
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }

            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .frame(height: 30)
        .background(MHBTheme.ColorToken.background.color)
        .clipShape(Capsule())
    }
}
