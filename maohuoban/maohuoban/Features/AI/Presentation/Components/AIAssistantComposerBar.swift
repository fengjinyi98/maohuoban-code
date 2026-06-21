import SwiftUI
import MaohuobanDesignSystem

// AIAssistantComposerBar AI 助手输入栏
// 核心职责：
// - 承载用户问题输入与发送按钮
// - 将发送动作作为显式事件交给上层 Store
struct AIAssistantComposerBar: View {
    @Binding var draftText: String
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: MHBTheme.Spacing.s3) {
            TextField("问问毛伙伴 AI", text: $draftText, axis: .vertical)
                .font(MHBTheme.Typography.body)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1...4)
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .padding(.vertical, MHBTheme.Spacing.s2)
                .frame(minHeight: 42)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(canSend ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelQuaternary.color)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("发送")
            .accessibilityIdentifier("ai.assistant.sendButton")
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.top, MHBTheme.Spacing.s3)
        .padding(.bottom, MHBTheme.Spacing.s3)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separator.color)
                .frame(height: 1)
        }
        .accessibilityIdentifier("ai.assistant.composer")
    }
}
