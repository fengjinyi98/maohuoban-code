import SwiftUI
import MaohuobanDesignSystem

// AIAssistantListItemView AI 列表行
// 核心职责：
// - 渲染单个列表项
// - 固定项目符号宽度避免多行错位
struct AIAssistantListItemView: View {
    let item: AIAssistantRichTextLineBlock

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
            Text("•")
                .font(MHBTheme.Typography.headline.weight(.regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 12, alignment: .center)
            AIAssistantRichTextLineView(
                spans: item.spans,
                font: MHBTheme.Typography.headline.weight(.regular),
                color: MHBTheme.ColorToken.labelPrimary.color,
                lineSpacing: 3
            )
        }
    }
}
