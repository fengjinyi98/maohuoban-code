import SwiftUI
import MaohuobanDesignSystem

// AIAssistantContentBlockList AI 内容块列表
// 核心职责：
// - 按顺序渲染后端确认过的语义内容块
// - 保持内容块之间的排版流间距
struct AIAssistantContentBlockList: View {
    let blocks: [AIAssistantContentBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            ForEach(blocks) { block in
                AIAssistantContentBlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
