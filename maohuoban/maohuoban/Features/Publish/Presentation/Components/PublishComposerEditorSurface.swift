import SwiftUI
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
    let onDismissKeyboard: () -> Void
    let onRemoveMedia: (UUID) -> Void
    let onRemoveArticleImageBlock: (UUID) -> Void
    let onReplaceArticleImageBlock: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            switch mode {
            case .gallery:
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
                    onMentionUser: onMentionUser,
                    onDismissKeyboard: onDismissKeyboard
                )

            case .richText:
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
                    onDismissKeyboard: onDismissKeyboard,
                    onRemoveImageBlock: onRemoveArticleImageBlock,
                    onReplaceImageBlock: onReplaceArticleImageBlock
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("publish.editor.surface")
    }
}
