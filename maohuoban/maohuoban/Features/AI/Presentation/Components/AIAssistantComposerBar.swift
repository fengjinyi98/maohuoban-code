import SwiftUI
import MaohuobanDesignSystem
import UIKit

// AIAssistantComposerBar AI 助手输入栏
// 核心职责：
// - 承载用户问题输入与发送按钮
// - 将发送动作作为显式事件交给上层 Store
struct AIAssistantComposerBar: View {
    let prompts: [AIAssistantSuggestedPrompt]
    let selectedAttachment: AIAssistantSelectedAttachment?
    let selectedAttachmentImage: UIImage?
    @Binding var draftText: String
    let canSend: Bool
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
                draftText: $draftText,
                canSend: canSend,
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

// AIAssistantComposerSurface AI 助手输入玻璃容器
// 核心职责：
// - 承载加号菜单、可自适应高度文本输入和发送按钮
// - 使用 Liquid Glass 形成贴近系统的底部输入体验
private struct AIAssistantComposerSurface: View {
    let selectedAttachment: AIAssistantSelectedAttachment?
    let selectedAttachmentImage: UIImage?
    @Binding var draftText: String
    let canSend: Bool
    let onSelectAttachmentSource: (AIAssistantAttachmentSource) -> Void
    let onClearAttachmentSource: () -> Void
    let onSend: () -> Void

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

                TextField("询问毛球", text: $draftText, axis: .vertical)
                    .font(MHBTheme.Typography.body)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1...5)
                    .textInputAutocapitalization(.never)
            }
            .frame(minHeight: 34, alignment: .leading)

            Button(action: onSend) {
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

// AIAssistantAttachmentMenu AI 附件来源菜单
// 核心职责：
// - 提供相机和相册两个媒体入口
// - 将选择事件交给上层状态容器
private struct AIAssistantAttachmentMenu: View {
    let onSelectAttachmentSource: (AIAssistantAttachmentSource) -> Void

    var body: some View {
        Menu {
            Button {
                onSelectAttachmentSource(.camera)
            } label: {
                Label("相机", systemImage: "camera.fill")
            }

            Button {
                onSelectAttachmentSource(.photoLibrary)
            } label: {
                Label("相册", systemImage: "photo.on.rectangle.angled")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 27, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加附件")
        .accessibilityIdentifier("ai.assistant.attachmentMenu")
    }
}

// AIAssistantAttachmentSelectionChip 附件来源选择提示
// 核心职责：
// - 展示用户刚选择的媒体来源
// - 提供清除当前选择的显式按钮
private struct AIAssistantAttachmentSelectionChip: View {
    let title: String
    let image: UIImage?
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
            }

            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("清除附件来源")
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .frame(height: 24)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(Capsule())
    }
}
