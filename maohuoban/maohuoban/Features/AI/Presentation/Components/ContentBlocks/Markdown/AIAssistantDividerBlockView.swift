import SwiftUI
import MaohuobanDesignSystem

// AIAssistantDividerBlockView AI 分割线内容块
// 核心职责：
// - 渲染模型 Markdown 分割线
// - 保持对话正文中的轻量视觉分隔
struct AIAssistantDividerBlockView: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separator.color.opacity(0.7))
            .frame(height: 1)
            .padding(.vertical, MHBTheme.Spacing.s1)
            .accessibilityIdentifier("ai.assistant.block.divider")
    }
}
