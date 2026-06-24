import SwiftUI

// PublishGalleryEditor 画廊模式编辑器
struct PublishGalleryEditor: View {
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
