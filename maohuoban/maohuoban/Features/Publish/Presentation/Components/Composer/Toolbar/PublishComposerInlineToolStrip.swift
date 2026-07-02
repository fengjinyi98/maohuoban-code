import SwiftUI
import MaohuobanDesignSystem

// PublishComposerInlineToolStrip 发布正文快捷工具条
// 核心职责：
// - 对齐旧版发布正文区的横向插入工具条
// - 为图文和画廊正文提供话题、用户提及和键盘收起入口
struct PublishComposerInlineToolStrip: View {
    let canAddMedia: Bool
    let onAddMedia: () -> Void
    let onInsertTopic: () -> Void
    let onMentionUser: () -> Void
    let onDismissKeyboard: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if canAddMedia {
                    PublishComposerInlineToolButton(
                        iconName: "photo.badge.plus",
                        title: "插入图片",
                        action: onAddMedia
                    )
                }

                PublishComposerInlineToolButton(
                    symbol: "#",
                    title: "话题",
                    action: onInsertTopic
                )

                PublishComposerInlineToolButton(
                    symbol: "@",
                    title: "用户",
                    action: onMentionUser
                )

                PublishComposerKeyboardDismissButton(
                    action: onDismissKeyboard
                )
            }
        }
        .scrollIndicators(.hidden)
    }
}

// PublishComposerInlineToolButton 发布正文快捷按钮
// 核心职责：
// - 用统一胶囊样式承载发布正文工具入口
// - 稳定按钮高度和横向间距以贴近旧版布局
struct PublishComposerInlineToolButton: View {
    let iconName: String?
    let symbol: String?
    let title: String
    let action: () -> Void

    init(
        iconName: String,
        title: String,
        action: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.symbol = nil
        self.title = title
        self.action = action
    }

    init(
        symbol: String,
        title: String,
        action: @escaping () -> Void
    ) {
        self.iconName = nil
        self.symbol = symbol
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(MHBTheme.Typography.callout)
                }

                if let symbol {
                    Text(symbol)
                        .font(MHBTheme.Typography.callout.weight(.bold))
                }

                Text(title)
                    .font(MHBTheme.Typography.callout)
            }
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s2)
            .background(MHBTheme.ColorToken.separatorSoft.color, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// PublishComposerKeyboardDismissButton 发布正文键盘收起按钮
// 核心职责：
// - 在正文工具条中提供明确的收起键盘入口
struct PublishComposerKeyboardDismissButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 40, height: 36)
                .background(MHBTheme.ColorToken.separatorSoft.color, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("收起键盘")
    }
}
