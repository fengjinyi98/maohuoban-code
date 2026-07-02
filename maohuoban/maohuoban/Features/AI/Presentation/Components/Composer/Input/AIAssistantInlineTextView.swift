import SwiftUI
import MaohuobanDesignSystem

// AIAssistantInlineTextView AI 行内富文本视图
// 核心职责：
// - 渲染流式正文纯文本
// - 展示流式输出光标
struct AIAssistantInlineTextView: View {
    let text: String
    let showsStreamingCursor: Bool

    var body: some View {
        Text("\(text)\(showsStreamingCursor ? " ▎" : "")")
            .font(MHBTheme.Typography.headline.weight(.regular))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
