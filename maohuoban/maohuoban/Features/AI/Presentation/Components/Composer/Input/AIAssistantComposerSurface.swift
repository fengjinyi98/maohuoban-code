import SwiftUI
import MaohuobanDesignSystem
import UIKit

// AIAssistantComposerSurface AI 助手输入玻璃容器
// 核心职责：
// - 承载加号菜单、可自适应高度文本输入和发送按钮
// - 使用 Liquid Glass 形成贴近系统的底部输入体验
struct AIAssistantComposerSurface: View {
    let selectedAttachment: AIAssistantSelectedAttachment?
    let selectedAttachmentImage: UIImage?
    @Binding var isInputFocused: Bool
    let isInputFirstResponderAllowed: Bool
    @Bindable var store: AIAssistantStore
    @State private var inputHeight: CGFloat = 34
    let onSelectAttachmentSource: (AIAssistantAttachmentSource) -> Void
    let onClearAttachmentSource: () -> Void
    let onSend: () -> Void

    private var draftTextBinding: Binding<String> {
        Binding(
            get: {
                store.draftText
            },
            set: { newValue in
                store.draftText = newValue
            }
        )
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: MHBTheme.Spacing.s2) {
            AIAssistantAttachmentMenu(
                onSelectAttachmentSource: onSelectAttachmentSource
            )

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                if let selectedAttachment {
                    AIAssistantAttachmentSelectionChip(
                        title: selectedAttachment.title,
                        image: selectedAttachmentImage,
                        onClear: onClearAttachmentSource
                    )
                }

                MHBStableMultilineTextInput(
                    text: draftTextBinding,
                    isFocused: $isInputFocused,
                    dynamicHeight: $inputHeight,
                    font: MHBTheme.Typography.uiBody,
                    textColor: MHBTheme.ColorToken.labelPrimary.uiColor,
                    placeholder: "询问毛球",
                    placeholderColor: MHBTheme.ColorToken.labelTertiary.uiColor,
                    tintColor: MHBTheme.ColorToken.primary.uiColor,
                    minHeight: 34,
                    maxHeight: 110,
                    allowsFirstResponder: isInputFirstResponderAllowed
                )
                .frame(height: max(inputHeight, 34))
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isInputFirstResponderAllowed else { return }
                isInputFocused = true
            }

            AIAssistantSendButton(
                store: store,
                onSend: onSend
            )
        }
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .frame(minHeight: 56)
        .background {
            Color.white.opacity(0.10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }
}
