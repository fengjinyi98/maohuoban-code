import SwiftUI
import MaohuobanDesignSystem

// AIAssistantComposerBar AI 助手输入栏
// 核心职责：
// - 承载用户问题输入与发送按钮
// - 将发送动作作为显式事件交给上层 Store
// 设计说明：
// - 使用 @Bindable 直接持有 store 引用而非 @Binding draftText，
//   由稳定输入基础设施处理输入法组合态和动态高度同步。
struct AIAssistantComposerBar: View {
    let prompts: [AIAssistantSuggestedPrompt]
    let selectedAttachment: AIAssistantSelectedAttachment?
    let selectedAttachmentImage: UIImage?
    @Binding var isInputFocused: Bool
    let isInputFirstResponderAllowed: Bool
    @Bindable var store: AIAssistantStore
    let onSelectPrompt: (AIAssistantSuggestedPrompt) -> Void
    let onSelectAttachmentSource: (AIAssistantAttachmentSource) -> Void
    let onClearAttachmentSource: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            if prompts.isEmpty == false {
                AIAssistantPromptRail(
                    prompts: prompts,
                    onSelect: onSelectPrompt
                )
            }

            AIAssistantComposerSurface(
                selectedAttachment: selectedAttachment,
                selectedAttachmentImage: selectedAttachmentImage,
                isInputFocused: $isInputFocused,
                isInputFirstResponderAllowed: isInputFirstResponderAllowed,
                store: store,
                onSelectAttachmentSource: onSelectAttachmentSource,
                onClearAttachmentSource: onClearAttachmentSource,
                onSend: onSend
            )
            .padding(.horizontal, MHBTheme.Spacing.s4)
        }
        .padding(.top, MHBTheme.Spacing.s2)
        .padding(.bottom, MHBTheme.Spacing.s5)
        .accessibilityIdentifier("ai.assistant.composer")
    }
}
