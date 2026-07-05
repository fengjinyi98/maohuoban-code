import SwiftUI
import MaohuobanDesignSystem

// AIAssistantMessageTimeSeparator AI 消息时间分隔
// 核心职责：
// - 展示会话首条消息的创建时间
// - 使用轻量文字弱化对消息内容的干扰
struct AIAssistantMessageTimeSeparator: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MHBTheme.Typography.callout.weight(.semibold))
            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, MHBTheme.Spacing.s2)
            .padding(.bottom, MHBTheme.Spacing.s4)
            .accessibilityIdentifier("ai.assistant.message.timeSeparator")
    }
}
