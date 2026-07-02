import Foundation
import Proton
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishArticleRichTextEditorCoordinator 编辑器委托与块同步
// 核心职责：
// - 处理 Proton EditorView 的全部委托回调
// - 维护 blocks 数组与编辑器内容的双向同步
// - 实现富文本到文章块的序列化
extension PublishArticleRichTextEditorCoordinator {
    @MainActor
    static func serializeBlocks(
        from attributedText: NSAttributedString,
        previousBlocks: [PublishArticleBlock]
    ) -> [PublishArticleBlock] {
        guard attributedText.length > 0 else { return [] }

        var blocks: [PublishArticleBlock] = []
        var cursor = 0
        var textBuffer = ""
        var blockIndex = 0

        func flushTextBuffer() {
            let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                let reusedID: UUID
                if previousBlocks.indices.contains(blockIndex),
                   previousBlocks[blockIndex].kind == .text {
                    reusedID = previousBlocks[blockIndex].id
                } else {
                    reusedID = UUID()
                }
                blocks.append(PublishArticleBlock(id: reusedID, kind: .text, text: trimmed))
                blockIndex += 1
            }
            textBuffer = ""
        }

        while cursor < attributedText.length {
            var effectiveRange = NSRange(location: 0, length: 0)
            if let attachment = attributedText.attribute(
                .attachment,
                at: cursor,
                longestEffectiveRange: &effectiveRange,
                in: NSRange(location: 0, length: attributedText.length)
            ) as? Attachment,
               let imageView = attachment.contentView as? PublishArticleImageAttachmentView {
                flushTextBuffer()
                blocks.append(
                    PublishArticleBlock(
                        id: imageView.blockID,
                        kind: .image,
                        text: imageView.caption,
                        mediaID: imageView.mediaID
                    )
                )
                blockIndex += 1
                cursor = effectiveRange.location + effectiveRange.length
                while cursor < attributedText.length {
                    let value = attributedText.attributedSubstring(
                        from: NSRange(location: cursor, length: 1)
                    ).string
                    if value == "\n" || value == " " {
                        cursor += 1
                    } else {
                        break
                    }
                }
                continue
            }

            textBuffer.append(
                attributedText.attributedSubstring(from: NSRange(location: cursor, length: 1)).string
            )
            cursor += 1
        }

        flushTextBuffer()
        return blocks
    }

    nonisolated func editor(_ editor: EditorView, didChangeTextAt range: NSRange) {
        Task { @MainActor [weak self, weak editor] in
            guard let self, let editor else { return }
            if editor.markedTextRange != nil {
                return
            }
            let committedText = editor.attributedText.string
            if self.ignoredCommittedTextChangeCount > 0 {
                self.ignoredCommittedTextChangeCount -= 1
                return
            }
            let scheduledSnapshot = self.commitSyncGate.recordCommittedSnapshot(committedText)
            await Task.yield()
            let currentText = editor.attributedText.string
            let isMarked = editor.markedTextRange != nil
            guard self.commitSyncGate.shouldApply(
                scheduledSnapshot: scheduledSnapshot,
                currentText: currentText,
                isMarked: isMarked
            ) else {
                return
            }
            self.commitSyncGate.finish(scheduledSnapshot: scheduledSnapshot)
            self.syncBlocks(from: editor)
        }
    }

    nonisolated func editor(
        _ editor: EditorView,
        shouldHandle key: EditorKey,
        modifierFlags: UIKeyModifierFlags,
        at range: NSRange,
        handled: inout Bool
    ) {
        guard key == .backspace else { return }

        let affectedRange: NSRange
        if range.length > 0 {
            affectedRange = range
        } else {
            guard range.location > 0 else { return }
            affectedRange = NSRange(location: range.location - 1, length: 1)
        }

        let shouldHandleTopicDeletion = MainActor.assumeIsolated {
            PublishTopicTokenController.topicTokenRangeForDeletion(
                in: editor.attributedText,
                affectedRange: affectedRange
            ) != nil
        }
        guard shouldHandleTopicDeletion else { return }

        handled = true
        Task { @MainActor [weak self, weak editor] in
            guard let self, let editor else { return }
            self.deleteTopicToken(in: editor, selectionRange: range)
        }
    }

    nonisolated func editor(_ editor: EditorView, didTapAtLocation location: CGPoint, characterRange: NSRange?) {
        let topicRange = MainActor.assumeIsolated {
            let tapLocation = characterRange?.location ?? editor.selectedRange.location
            return PublishTopicTokenController.topicTokenRangeForTap(
                in: editor.attributedText,
                location: tapLocation
            )
        }
        guard let topicRange else { return }

        Task { @MainActor [weak editor] in
            guard let editor else { return }
            editor.selectedRange = NSRange(
                location: topicRange.location + topicRange.length,
                length: 0
            )
            editor.becomeFirstResponder()
        }
    }

    nonisolated func editor(
        _ editor: EditorView,
        didChangeSelectionAt range: NSRange,
        attributes: [NSAttributedString.Key: Any],
        contentType: EditorContent.Name
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastKnownSelectionRange = range
            self.scheduleTopicSyncIfNeeded(from: editor)
        }
    }

    nonisolated func editor(_ editor: EditorView, didReceiveFocusAt range: NSRange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastKnownSelectionRange = range
        }
    }

    nonisolated func editor(_ editor: EditorView, didChangeSize currentSize: CGSize, previousSize: CGSize) {
        DispatchQueue.main.async { [weak self] in
            self?.updateHeight(from: editor)
        }
    }

    @MainActor
    func deleteTopicToken(in editor: EditorView, selectionRange: NSRange) {
        let affectedRange: NSRange
        if selectionRange.length > 0 {
            affectedRange = selectionRange
        } else {
            guard selectionRange.location > 0 else { return }
            affectedRange = NSRange(location: selectionRange.location - 1, length: 1)
        }

        guard let topicRange = PublishTopicTokenController.topicTokenRangeForDeletion(
            in: editor.attributedText,
            affectedRange: affectedRange
        ) else {
            return
        }

        let content = NSMutableAttributedString(attributedString: editor.attributedText)
        content.replaceCharacters(in: topicRange, with: "")

        isApplyingBlocks = true
        markNextCommittedTextChangeAsProgrammatic()
        editor.attributedText = content
        editor.selectedRange = NSRange(location: min(topicRange.location, content.length), length: 0)
        isApplyingBlocks = false
        syncBlocks(from: editor)
    }

    @MainActor
    func updateCaption(blockID: UUID, caption: String) {
        var nextBlocks = renderedBlocks
        guard let index = nextBlocks.firstIndex(where: { $0.id == blockID }) else { return }
        nextBlocks[index].text = caption
        renderedBlocks = nextBlocks
        pendingParentBlocks = nextBlocks
        DispatchQueue.main.async { [weak self] in
            self?.parent.blocks = nextBlocks
        }
    }

    @MainActor
    func syncBlocks(from editor: EditorView) {
        guard isApplyingBlocks == false else { return }
        if editor.markedTextRange != nil {
            return
        }

        let content = NSMutableAttributedString(attributedString: editor.attributedText)
        let reconcileResult = PublishTopicTokenController.reconcileTopics(
            in: content,
            defaultColor: MHBTheme.ColorToken.labelPrimary.publishUIKitColor
        )
        activeTopicAnchorLocation = reconcileResult.activeAnchorLocation
        let currentSelection = editor.selectedRange
        if content.isEqual(editor.attributedText) == false {
            isApplyingBlocks = true
            markNextCommittedTextChangeAsProgrammatic()
            editor.attributedText = content
            editor.selectedRange = NSRange(location: min(currentSelection.location, content.length), length: 0)
            isApplyingBlocks = false
        }
        DispatchQueue.main.async { [weak self] in
            self?.parent.onTopicsChange(reconcileResult.topicNames)
        }

        let nextBlocks = Self.serializeBlocks(from: content, previousBlocks: renderedBlocks)
        renderedBlocks = nextBlocks
        pendingParentBlocks = nextBlocks
        DispatchQueue.main.async { [weak self, weak editor] in
            guard let self, let editor else { return }
            guard editor.attributedText.string == content.string else {
                return
            }
            self.parent.blocks = nextBlocks
        }
        updateHeight(from: editor)
    }

    @MainActor
    func scheduleTopicSyncIfNeeded(from editor: EditorView) {
        guard isApplyingBlocks == false else { return }
        guard editor.markedTextRange == nil else { return }
        let text = editor.attributedText.string
        guard text.contains("#") else { return }

        let nextBlocks = Self.serializeBlocks(
            from: editor.attributedText,
            previousBlocks: renderedBlocks
        )
        guard nextBlocks != renderedBlocks else { return }

        scheduledSelectionSyncToken += 1
        let token = scheduledSelectionSyncToken
        DispatchQueue.main.async { [weak self, weak editor] in
            guard let self, let editor else { return }
            guard self.scheduledSelectionSyncToken == token else { return }
            guard self.isApplyingBlocks == false else { return }
            guard editor.markedTextRange == nil else { return }
            let latestBlocks = Self.serializeBlocks(
                from: editor.attributedText,
                previousBlocks: self.renderedBlocks
            )
            guard latestBlocks != self.renderedBlocks else { return }
            self.syncBlocks(from: editor)
        }
    }
}
