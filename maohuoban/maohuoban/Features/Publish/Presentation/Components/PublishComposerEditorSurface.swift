import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishComposerEditorSurface 发布编辑器主体
// 核心职责：
// - 根据发布模式展示不同的排版布局（小红书风格）：
//   1. Gallery Mode (画廊模式): 横向图片预览栏在最顶部，随后是正文编辑区（无标题）
//   2. Rich Text Mode (图文模式): 依次是标题输入框、正文编辑区、内嵌大图展示区（添加照片按钮置于正文下方）
struct PublishComposerEditorSurface: View {
    let mode: PublishComposerMode
    let selectedImages: [PublishSelectedImage]
    let canAddMore: Bool
    let pendingInsertedArticleMediaIDs: [UUID]
    let pendingTopicInsertionNonce: Int
    let pendingMentionInsertionNonce: Int
    @Binding var title: String
    @Binding var bodyText: String
    @Binding var articleBlocks: [PublishArticleBlock]
    let onPendingArticleMediaInsertionHandled: ([UUID]) -> Void
    let onPendingTopicInsertionHandled: () -> Void
    let onPendingMentionInsertionHandled: () -> Void
    let onTopicsChange: ([String]) -> Void
    let onAddMedia: () -> Void
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
                    onPendingTopicInsertionHandled: onPendingTopicInsertionHandled,
                    onPendingMentionInsertionHandled: onPendingMentionInsertionHandled,
                    onTopicsChange: onTopicsChange
                )
                
            case .richText:
                // 图文模式：标题、正文在前，图片预览/添加器在后
                PublishRichTextEditor(
                    selectedImages: selectedImages,
                    canAddMore: canAddMore,
                    title: $title,
                    bodyText: $bodyText,
                    articleBlocks: $articleBlocks,
                    pendingInsertedMediaIDs: pendingInsertedArticleMediaIDs,
                    pendingTopicInsertionNonce: pendingTopicInsertionNonce,
                    pendingMentionInsertionNonce: pendingMentionInsertionNonce,
                    onPendingMediaInsertionHandled: onPendingArticleMediaInsertionHandled,
                    onPendingTopicInsertionHandled: onPendingTopicInsertionHandled,
                    onPendingMentionInsertionHandled: onPendingMentionInsertionHandled,
                    onTopicsChange: onTopicsChange,
                    onAddMedia: onAddMedia,
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
    @Binding var bodyText: String
    @Binding var articleBlocks: [PublishArticleBlock]
    let pendingInsertedMediaIDs: [UUID]
    let pendingTopicInsertionNonce: Int
    let pendingMentionInsertionNonce: Int
    let onPendingMediaInsertionHandled: ([UUID]) -> Void
    let onPendingTopicInsertionHandled: () -> Void
    let onPendingMentionInsertionHandled: () -> Void
    let onTopicsChange: ([String]) -> Void
    let onAddMedia: () -> Void
    let onRemoveImageBlock: (UUID) -> Void
    let onReplaceImageBlock: (UUID) -> Void

    @State private var editorHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // 标题
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                TextField("添加标题", text: $title)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .accessibilityIdentifier("publish.titleInput")

                HStack {
                    Rectangle()
                        .fill(MHBTheme.ColorToken.separatorSoft.color)
                        .frame(height: 1)

                    Text("\(title.count)/\(PublishDraftStore.maxTitleCharacterCount)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .monospacedDigit()
                }
            }

            // 正文
            PublishArticleRichTextEditor(
                blocks: $articleBlocks,
                editorHeight: $editorHeight,
                selectedImages: selectedImages,
                pendingInsertedMediaIDs: pendingInsertedMediaIDs,
                pendingTopicInsertionNonce: pendingTopicInsertionNonce,
                pendingMentionInsertionNonce: pendingMentionInsertionNonce,
                onPendingInsertionHandled: onPendingMediaInsertionHandled,
                onPendingTopicInsertionHandled: onPendingTopicInsertionHandled,
                onPendingMentionInsertionHandled: onPendingMentionInsertionHandled,
                onTopicsChange: onTopicsChange,
                onRemoveImageBlock: onRemoveImageBlock,
                onReplaceImageBlock: onReplaceImageBlock
            )
            .frame(height: editorHeight)
            .accessibilityIdentifier("publish.bodyInput")

            // 图文模式的图片会插入富文本流，这里只保留插入入口
            if canAddMore, selectedImages.isEmpty {
                PublishInlineMediaPlaceholder(onAddMedia: onAddMedia)
            } else if canAddMore {
                PublishInsertMediaFocus(onAddMedia: onAddMedia)
            }
        }
    }
}

// PublishGalleryEditor 画廊模式编辑器
private struct PublishGalleryEditor: View {
    @Binding var bodyText: String
    let pendingTopicInsertionNonce: Int
    let pendingMentionInsertionNonce: Int
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
