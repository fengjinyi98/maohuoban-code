import SwiftUI
import MaohuobanDesignSystem

// AIAssistantScrollToLatestButton AI 回到最新消息按钮
// 核心职责：
// - 在用户离开会话底部后提供快速回到底部入口
// - 使用 Liquid Glass 容器匹配输入框上方悬浮层
struct AIAssistantScrollToLatestButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background {
            Color.white.opacity(0.10)
        }
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("滚动到最新消息")
        .accessibilityIdentifier("ai.assistant.scrollToLatest")
    }
}
