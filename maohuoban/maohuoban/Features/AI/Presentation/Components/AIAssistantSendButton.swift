import SwiftUI
import MaohuobanDesignSystem

// AIAssistantSendButton AI 助手发送按钮
// 核心职责：
// - 根据流式状态和草稿内容计算可发送状态
// - 渲染发送按钮并承载禁用逻辑
struct AIAssistantSendButton: View {
    @Bindable var store: AIAssistantStore
    let onSend: () -> Void

    private var canSend: Bool {
        store.isStreaming == false
            && store.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        Button {
            onSend()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(canSend ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelQuaternary.color)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel("发送")
        .accessibilityIdentifier("ai.assistant.sendButton")
    }
}
