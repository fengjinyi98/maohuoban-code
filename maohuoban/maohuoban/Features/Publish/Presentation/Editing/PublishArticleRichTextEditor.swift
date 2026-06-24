import Foundation
import Proton
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishArticleRichTextEditor 图文富文本编辑器宿主
// 核心职责：
// - 用 Proton 承载连续文本输入和图片块附件
// - 把编辑器内容实时还原为图文发布使用的 block 数组
struct PublishArticleRichTextEditor: UIViewRepresentable {
    @Binding var blocks: [PublishArticleBlock]
    @Binding var editorHeight: CGFloat

    let selectedImages: [PublishSelectedImage]
    let pendingInsertedMediaIDs: [UUID]
    let pendingTopicInsertionNonce: Int
    let pendingMentionInsertionNonce: Int
    let pendingMentionInsertionText: String?
    let onPendingInsertionHandled: ([UUID]) -> Void
    let onPendingTopicInsertionHandled: () -> Void
    let onPendingMentionInsertionHandled: () -> Void
    let onTopicsChange: ([String]) -> Void
    let onRemoveImageBlock: (UUID) -> Void
    let onReplaceImageBlock: (UUID) -> Void

    func makeCoordinator() -> PublishArticleRichTextEditorCoordinator {
        PublishArticleRichTextEditorCoordinator(parent: self)
    }

    func makeUIView(context: Context) -> EditorView {
        let editor = EditorView()
        editor.delegate = context.coordinator
        context.coordinator.selectedImages = selectedImages
        editor.isScrollEnabled = false
        editor.backgroundColor = .clear
        editor.textColor = MHBTheme.ColorToken.labelPrimary.publishUIKitColor
        editor.tintColor = MHBTheme.ColorToken.primary.publishUIKitColor
        editor.font = Self.textFont
        editor.textContainerInset = .zero
        editor.placeholderText = NSAttributedString(
            string: "添加正文",
            attributes: [
                .font: Self.textFont,
                .foregroundColor: MHBTheme.ColorToken.labelTertiary.publishUIKitColor,
            ]
        )
        editor.setContentCompressionResistancePriority(.required, for: .vertical)
        context.coordinator.applyBlocks(blocks, to: editor)
        DispatchQueue.main.async {
            context.coordinator.updateHeight(from: editor)
        }
        return editor
    }

    func updateUIView(_ uiView: EditorView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.selectedImages = selectedImages
        uiView.textColor = MHBTheme.ColorToken.labelPrimary.publishUIKitColor
        uiView.tintColor = MHBTheme.ColorToken.primary.publishUIKitColor

        if let placeholder = uiView.placeholderText {
            let nextPlaceholder = NSMutableAttributedString(attributedString: placeholder)
            nextPlaceholder.addAttributes(
                [
                    .font: Self.textFont,
                    .foregroundColor: MHBTheme.ColorToken.labelTertiary.publishUIKitColor,
                ],
                range: NSRange(location: 0, length: nextPlaceholder.length)
            )
            uiView.placeholderText = nextPlaceholder
        }

        if uiView.markedTextRange != nil {
            return
        }

        let currentMediaIDs = selectedImages.map(\.id)
        var shouldProcessIncomingBlocks = true
        if context.coordinator.pendingParentBlocks == blocks {
            context.coordinator.pendingParentBlocks = nil
        } else if context.coordinator.shouldIgnoreIncomingBlocks(blocks, in: uiView) {
            shouldProcessIncomingBlocks = false
        }

        if shouldProcessIncomingBlocks, context.coordinator.renderedBlocks != blocks {
            if context.coordinator.canRefreshAttachmentsInPlace(
                from: context.coordinator.renderedBlocks,
                to: blocks
            ) {
                let changedBlockIDs = context.coordinator.changedImageBlockIDs(
                    from: context.coordinator.renderedBlocks,
                    to: blocks
                )
                let changedMediaIDs = context.coordinator.changedMediaIDs(
                    from: context.coordinator.renderedMediaIDs,
                    to: currentMediaIDs
                )
                let affectedBlockIDs = changedBlockIDs.union(
                    blocks.compactMap { block in
                        guard let mediaID = block.mediaID,
                              changedMediaIDs.contains(mediaID) else {
                            return nil
                        }
                        return block.id
                    }
                )
                context.coordinator.renderedBlocks = blocks
                context.coordinator.renderedMediaIDs = currentMediaIDs
                if affectedBlockIDs.isEmpty == false {
                    context.coordinator.refreshAttachmentViews(
                        in: uiView,
                        blocks: blocks,
                        onlyBlockIDs: affectedBlockIDs
                    )
                }
            } else {
                context.coordinator.applyBlocks(blocks, to: uiView)
            }
        } else if shouldProcessIncomingBlocks {
            let changedMediaIDs = context.coordinator.changedMediaIDs(
                from: context.coordinator.renderedMediaIDs,
                to: currentMediaIDs
            )
            if changedMediaIDs.isEmpty == false {
                context.coordinator.renderedMediaIDs = currentMediaIDs
                context.coordinator.refreshAttachmentViews(
                    in: uiView,
                    blocks: blocks,
                    onlyMediaIDs: changedMediaIDs
                )
            }
        }

        let handledMediaIDs = context.coordinator.insertPendingImagesIfNeeded(
            pendingInsertedMediaIDs,
            into: uiView
        )
        if handledMediaIDs.isEmpty == false {
            DispatchQueue.main.async {
                onPendingInsertionHandled(handledMediaIDs)
            }
        }

        if pendingTopicInsertionNonce > context.coordinator.lastHandledPendingTopicInsertionNonce {
            context.coordinator.insertTopic(into: uiView)
            context.coordinator.lastHandledPendingTopicInsertionNonce = pendingTopicInsertionNonce
            DispatchQueue.main.async {
                onPendingTopicInsertionHandled()
            }
        }

        if pendingMentionInsertionNonce > context.coordinator.lastHandledPendingMentionInsertionNonce {
            context.coordinator.insertMention(
                pendingMentionInsertionText ?? "@",
                into: uiView
            )
            context.coordinator.lastHandledPendingMentionInsertionNonce = pendingMentionInsertionNonce
            DispatchQueue.main.async {
                onPendingMentionInsertionHandled()
            }
        }

        DispatchQueue.main.async {
            context.coordinator.updateHeight(from: uiView)
        }
    }

    static var textFont: UIFont {
        UIFont.systemFont(ofSize: 15, weight: .regular)
    }
}
