import SwiftUI
import MaohuobanDesignSystem

// AIAssistantListBlockView AI 列表内容块
// 核心职责：
// - 渲染受控 Markdown 列表
// - 保持换行后正文与项目符号对齐
struct AIAssistantListBlockView: View {
    let block: AIAssistantListBlock

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            ForEach(Array(block.items.enumerated()), id: \.offset) { _, item in
                AIAssistantListItemView(item: item)
            }
        }
        .accessibilityIdentifier("ai.assistant.block.list")
    }
}
