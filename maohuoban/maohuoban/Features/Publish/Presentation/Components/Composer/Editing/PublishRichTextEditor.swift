import SwiftUI
import MaohuobanDesignSystem

// PublishRichTextEditor 图文模式编辑器
struct PublishRichTextEditor: View {
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
    let onDismissKeyboard: () -> Void
    let onRemoveImageBlock: (UUID) -> Void
    let onReplaceImageBlock: (UUID) -> Void

    @State private var editorHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                onMentionUser: onMentionUser,
                onDismissKeyboard: onDismissKeyboard
            )
            .padding(.bottom, 12)
        }
    }
}
