import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishComposerEditorSurface 发布编辑器主体
// 核心职责：
// - 根据发布模式展示不同的排版布局（小红书风格）：
//   1. Gallery Mode (画廊模式): 横向图片预览栏在最顶部，随后是正文编辑区（无标题）
//   2. Rich Text Mode (图文模式): 标题行、富文本正文和旧版图文工具条保持一致
struct PublishComposerEditorSurface: View {
    let mode: PublishComposerMode
    let selectedImages: [PublishSelectedImage]
    let canAddMore: Bool
    let pendingInsertedArticleMediaIDs: [UUID]
    let pendingTopicInsertionNonce: Int
    let pendingMentionInsertionNonce: Int
    let pendingMentionInsertionText: String?
    @Binding var title: String
    @Binding var bodyText: String
    @Binding var articleBlocks: [PublishArticleBlock]
    let onPendingArticleMediaInsertionHandled: ([UUID]) -> Void
    let onPendingTopicInsertionHandled: () -> Void
    let onPendingMentionInsertionHandled: () -> Void
    let onTopicsChange: ([String]) -> Void
    let onAddMedia: () -> Void
    let onInsertTopic: () -> Void
    let onMentionUser: () -> Void
    let onRemoveMedia: (UUID) -> Void
    let onRemoveArticleImageBlock: (UUID) -> Void
    let onReplaceArticleImageBlock: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            switch mode {
            case .gallery:
                // 画廊模式：滑动照片浏览器置于顶部
                PublishMediaHorizontalScroll(
                    selectedImages: selectedImages,
                    canAddMore: canAddMore,
                    onAddMedia: onAddMedia,
                    onRemoveMedia: onRemoveMedia
                )
                
                PublishGalleryEditor(
                    bodyText: $bodyText,
                    pendingTopicInsertionNonce: pendingTopicInsertionNonce,
                    pendingMentionInsertionNonce: pendingMentionInsertionNonce,
                    pendingMentionInsertionText: pendingMentionInsertionText,
                    onPendingTopicInsertionHandled: onPendingTopicInsertionHandled,
                    onPendingMentionInsertionHandled: onPendingMentionInsertionHandled,
                    onTopicsChange: onTopicsChange
                )

                PublishComposerInlineToolStrip(
                    canAddMedia: false,
                    onAddMedia: onAddMedia,
                    onInsertTopic: onInsertTopic,
                    onMentionUser: onMentionUser
                )
                
            case .richText:
                // 图文模式：标题、正文在前，图片预览/添加器在后
                PublishRichTextEditor(
                    selectedImages: selectedImages,
                    canAddMore: canAddMore,
                    title: $title,
                    articleBlocks: $articleBlocks,
                    pendingInsertedMediaIDs: pendingInsertedArticleMediaIDs,
                    pendingTopicInsertionNonce: pendingTopicInsertionNonce,
                    pendingMentionInsertionNonce: pendingMentionInsertionNonce,
                    pendingMentionInsertionText: pendingMentionInsertionText,
                    onPendingMediaInsertionHandled: onPendingArticleMediaInsertionHandled,
                    onPendingTopicInsertionHandled: onPendingTopicInsertionHandled,
                    onPendingMentionInsertionHandled: onPendingMentionInsertionHandled,
                    onTopicsChange: onTopicsChange,
                    onAddMedia: onAddMedia,
                    onInsertTopic: onInsertTopic,
                    onMentionUser: onMentionUser,
                    onRemoveImageBlock: onRemoveArticleImageBlock,
                    onReplaceImageBlock: onReplaceArticleImageBlock
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("publish.editor.surface")
    }
}

// PublishMediaHorizontalScroll 画廊横向图片选择预览栏
private struct PublishMediaHorizontalScroll: View {
    let selectedImages: [PublishSelectedImage]
    let canAddMore: Bool
    let onAddMedia: () -> Void
    let onRemoveMedia: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                ForEach(selectedImages) { selectedImage in
                    PublishGalleryImageTile(
                        selectedImage: selectedImage,
                        onRemoveMedia: onRemoveMedia
                    )
                }

                if canAddMore {
                    Button(action: onAddMedia) {
                        PublishGalleryAddTile()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("添加照片")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s1)
        }
        .padding(.horizontal, -MHBTheme.Spacing.s4)
    }
}

// PublishRichTextEditor 图文模式编辑器
private struct PublishRichTextEditor: View {
    let selectedImages: [PublishSelectedImage]
    let canAddMore: Bool
    @Binding var title: String
    @Binding var articleBlocks: [PublishArticleBlock]
    let pendingInsertedMediaIDs: [UUID]
    let pendingTopicInsertionNonce: Int
    let pendingMentionInsertionNonce: Int
    let pendingMentionInsertionText: String?
    let onPendingMediaInsertionHandled: ([UUID]) -> Void
    let onPendingTopicInsertionHandled: () -> Void
    let onPendingMentionInsertionHandled: () -> Void
    let onTopicsChange: ([String]) -> Void
    let onAddMedia: () -> Void
    let onInsertTopic: () -> Void
    let onMentionUser: () -> Void
    let onRemoveImageBlock: (UUID) -> Void
    let onReplaceImageBlock: (UUID) -> Void

    @State private var editorHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack(alignment: .top) {
                TextField("填写标题会有更多赞哦～", text: $title, axis: .vertical)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .accessibilityIdentifier("publish.titleInput")

                Text("\(title.count)/\(PublishDraftStore.maxTitleCharacterCount)")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .monospacedDigit()
                    .padding(.top, 6)
            }

            // 正文
            PublishArticleRichTextEditor(
                blocks: $articleBlocks,
                editorHeight: $editorHeight,
                selectedImages: selectedImages,
                pendingInsertedMediaIDs: pendingInsertedMediaIDs,
                pendingTopicInsertionNonce: pendingTopicInsertionNonce,
                pendingMentionInsertionNonce: pendingMentionInsertionNonce,
                pendingMentionInsertionText: pendingMentionInsertionText,
                onPendingInsertionHandled: onPendingMediaInsertionHandled,
                onPendingTopicInsertionHandled: onPendingTopicInsertionHandled,
                onPendingMentionInsertionHandled: onPendingMentionInsertionHandled,
                onTopicsChange: onTopicsChange,
                onRemoveImageBlock: onRemoveImageBlock,
                onReplaceImageBlock: onReplaceImageBlock
            )
            .frame(height: editorHeight)
            .padding(.bottom, 12)
            .accessibilityIdentifier("publish.bodyInput")

            PublishComposerInlineToolStrip(
                canAddMedia: canAddMore,
                onAddMedia: onAddMedia,
                onInsertTopic: onInsertTopic,
                onMentionUser: onMentionUser
            )
            .padding(.bottom, 12)
        }
    }
}

// PublishComposerInlineToolStrip 发布正文快捷工具条
// 核心职责：
// - 对齐旧版发布正文区的横向插入工具条
// - 为图文和画廊正文提供话题与用户提及入口
private struct PublishComposerInlineToolStrip: View {
    let canAddMedia: Bool
    let onAddMedia: () -> Void
    let onInsertTopic: () -> Void
    let onMentionUser: () -> Void

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
            }
        }
        .scrollIndicators(.hidden)
    }
}

// PublishComposerInlineToolButton 发布正文快捷按钮
// 核心职责：
// - 用统一胶囊样式承载发布正文工具入口
// - 稳定按钮高度和横向间距以贴近旧版布局
private struct PublishComposerInlineToolButton: View {
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

// PublishGalleryEditor 画廊模式编辑器
private struct PublishGalleryEditor: View {
    @Binding var bodyText: String
    let pendingTopicInsertionNonce: Int
    let pendingMentionInsertionNonce: Int
    let pendingMentionInsertionText: String?
    let onPendingTopicInsertionHandled: () -> Void
    let onPendingMentionInsertionHandled: () -> Void
    let onTopicsChange: ([String]) -> Void

    var body: some View {
        PublishTopicTextEditor(
            text: $bodyText,
            placeholder: "添加正文",
            minHeight: 220,
            pendingTopicInsertionNonce: pendingTopicInsertionNonce,
            pendingMentionInsertionNonce: pendingMentionInsertionNonce,
            pendingMentionInsertionText: pendingMentionInsertionText,
            onPendingTopicInsertionHandled: onPendingTopicInsertionHandled,
            onPendingMentionInsertionHandled: onPendingMentionInsertionHandled,
            onTopicsChange: onTopicsChange
        )
        .accessibilityIdentifier("publish.bodyInput")
    }
}

// PublishInlineMediaPlaceholder 图文插图占位入口
private struct PublishInlineMediaPlaceholder: View {
    let onAddMedia: () -> Void

    var body: some View {
        Button(action: onAddMedia) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "plus")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Text("添加照片")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(MHBTheme.ColorToken.separatorSoft.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("publish.inlineMedia.addButton")
    }
}

// PublishInsertMediaFocus 图文继续插入焦点
private struct PublishInsertMediaFocus: View {
    let onAddMedia: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)

            Button(action: onAddMedia) {
                Image(systemName: "plus")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .frame(width: 28, height: 28)
                    .background(MHBTheme.ColorToken.labelPrimary.color)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("继续插入图片")

            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
        }
        .padding(.vertical, MHBTheme.Spacing.s1)
    }
}

// PublishInlineImageBlock 图文内嵌图片块
private struct PublishInlineImageBlock: View {
    let selectedImage: PublishSelectedImage
    let onRemoveMedia: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: selectedImage.image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                        .stroke(MHBTheme.ColorToken.labelPrimary.color.opacity(0.12), lineWidth: 3)
                }

            PublishRemoveMediaButton {
                onRemoveMedia(selectedImage.id)
            }
            .padding(MHBTheme.Spacing.s3)
        }
    }
}

// PublishGalleryImageTile 画廊图片缩略块
private struct PublishGalleryImageTile: View {
    let selectedImage: PublishSelectedImage
    let onRemoveMedia: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: selectedImage.image)
                .resizable()
                .scaledToFill()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(MHBTheme.ColorToken.labelPrimary.color.opacity(0.12), lineWidth: 3)
                }

            PublishRemoveMediaButton {
                onRemoveMedia(selectedImage.id)
            }
            .padding(MHBTheme.Spacing.s1)
        }
        .frame(width: 86, height: 86)
    }
}

// PublishGalleryAddTile 画廊添加图片块
private struct PublishGalleryAddTile: View {
    var body: some View {
        ZStack {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .frame(width: 86, height: 86)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// PublishRemoveMediaButton 图片移除按钮
private struct PublishRemoveMediaButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                .frame(width: 28, height: 28)
                .background(MHBTheme.ColorToken.labelPrimary.color.opacity(0.62))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("移除图片")
    }
}
