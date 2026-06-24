import Foundation
import Proton
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishArticleRichTextEditorCoordinator 图文富文本编辑器协调器
// 核心职责：
// - 处理 Proton EditorView 的全部委托回调
// - 维护 blocks 数组与编辑器内容的双向同步
// - 处理图片插入、话题 token、用户提及等交互流程
final class PublishArticleRichTextEditorCoordinator: NSObject, EditorViewDelegate, @unchecked Sendable {
    var parent: PublishArticleRichTextEditor
    var renderedBlocks: [PublishArticleBlock] = []
    var renderedMediaIDs: [UUID] = []
    var lastHandledPendingTopicInsertionNonce: Int
    var lastHandledPendingMentionInsertionNonce: Int
    var selectedImages: [PublishSelectedImage] = []
    var pendingParentBlocks: [PublishArticleBlock]?

    var handledPendingMediaIDs = Set<UUID>()
    var isApplyingBlocks = false
    var activeTopicAnchorLocation: Int?
    var lastKnownSelectionRange = NSRange(location: 0, length: 0)
    var commitSyncGate = PublishCommittedTextSyncGate()
    var ignoredCommittedTextChangeCount = 0
    var scheduledSyncToken = 0
    var scheduledSelectionSyncToken = 0

    init(parent: PublishArticleRichTextEditor) {
        self.parent = parent
        self.lastHandledPendingTopicInsertionNonce = parent.pendingTopicInsertionNonce
        self.lastHandledPendingMentionInsertionNonce = parent.pendingMentionInsertionNonce
    }

    @MainActor
    func applyBlocks(_ blocks: [PublishArticleBlock], to editor: EditorView) {
        isApplyingBlocks = true
        defer { isApplyingBlocks = false }
        let selectionBeforeApplying = preferredSelectionRange(for: editor)
        let wasFirstResponder = editor.isFirstResponder

        let content = NSMutableAttributedString()
        for (index, block) in blocks.enumerated() {
            switch block.kind {
            case .text:
                if block.text.isEmpty == false {
                    let textContent = NSMutableAttributedString(
                        string: block.text,
                        attributes: [
                            .font: PublishArticleRichTextEditor.textFont,
                            .foregroundColor: MHBTheme.ColorToken.labelPrimary.publishUIKitColor,
                        ]
                    )
                    _ = PublishTopicTokenController.reconcileTopics(
                        in: textContent,
                        defaultColor: MHBTheme.ColorToken.labelPrimary.publishUIKitColor
                    )
                    content.append(textContent)
                }
            case .image:
                guard let mediaID = block.mediaID,
                      let item = selectedImages.first(where: { $0.id == mediaID }) else {
                    continue
                }
                let attachmentView = PublishArticleImageAttachmentView(
                    blockID: block.id,
                    mediaID: mediaID,
                    caption: block.text,
                    selectedImage: item,
                    onCaptionChange: { [weak self] blockID, caption in
                        self?.updateCaption(blockID: blockID, caption: caption)
                    },
                    onReplace: { [weak self] blockID in
                        self?.parent.onReplaceImageBlock(blockID)
                    },
                    onDelete: { [weak self] blockID in
                        self?.parent.onRemoveImageBlock(blockID)
                    }
                )
                let attachment = Attachment(attachmentView, size: .fullWidth)
                attachment.selectBeforeDelete = true
                content.append(attachment.string)
            }

            if index < blocks.count - 1 {
                content.append(NSAttributedString(string: "\n"))
            }
        }

        markNextCommittedTextChangeAsProgrammatic()
        editor.attributedText = content
        restoreSelection(
            on: editor,
            preferredRange: selectionBeforeApplying,
            shouldFocus: wasFirstResponder
        )
        refreshAttachmentViews(in: editor, blocks: blocks)
        renderedBlocks = blocks
        renderedMediaIDs = selectedImages.map(\.id)
        pendingParentBlocks = nil
        updateHeight(from: editor)
    }

    @MainActor
    func refreshAttachmentViews(
        in editor: EditorView,
        blocks: [PublishArticleBlock],
        onlyBlockIDs: Set<UUID>? = nil,
        onlyMediaIDs: Set<UUID>? = nil
    ) {
        let attributedText = editor.attributedText
        guard attributedText.length > 0 else { return }
        let blockMap = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })

        var cursor = 0
        while cursor < attributedText.length {
            var effectiveRange = NSRange(location: 0, length: 0)
            if let attachment = attributedText.attribute(
                .attachment,
                at: cursor,
                longestEffectiveRange: &effectiveRange,
                in: NSRange(location: 0, length: attributedText.length)
            ) as? Attachment,
               let imageView = attachment.contentView as? PublishArticleImageAttachmentView,
               let block = blockMap[imageView.blockID],
               let mediaID = block.mediaID,
               let item = selectedImages.first(where: { $0.id == mediaID }) {
                if let onlyBlockIDs, onlyBlockIDs.contains(imageView.blockID) == false {
                    cursor = max(effectiveRange.location + max(effectiveRange.length, 1), cursor + 1)
                    continue
                }
                if let onlyMediaIDs, onlyMediaIDs.contains(mediaID) == false {
                    cursor = max(effectiveRange.location + max(effectiveRange.length, 1), cursor + 1)
                    continue
                }
                imageView.updateItem(item)
            }
            cursor = max(effectiveRange.location + max(effectiveRange.length, 1), cursor + 1)
        }
    }

    @MainActor
    func canRefreshAttachmentsInPlace(
        from rendered: [PublishArticleBlock],
        to incoming: [PublishArticleBlock]
    ) -> Bool {
        guard rendered.count == incoming.count else { return false }
        for (left, right) in zip(rendered, incoming) {
            guard left.id == right.id, left.kind == right.kind else { return false }
        }
        return true
    }

    @MainActor
    func changedImageBlockIDs(
        from rendered: [PublishArticleBlock],
        to incoming: [PublishArticleBlock]
    ) -> Set<UUID> {
        guard rendered.count == incoming.count else {
            return Set(incoming.filter(\.isImage).map(\.id))
        }

        var changedBlockIDs = Set<UUID>()
        for (left, right) in zip(rendered, incoming) {
            guard left.id == right.id, left.kind == right.kind else {
                return Set(incoming.filter(\.isImage).map(\.id))
            }
            guard right.isImage else { continue }
            if left.mediaID != right.mediaID {
                changedBlockIDs.insert(right.id)
            }
        }
        return changedBlockIDs
    }

    @MainActor
    func changedMediaIDs(from rendered: [UUID], to incoming: [UUID]) -> Set<UUID> {
        let renderedSet = Set(rendered)
        let incomingSet = Set(incoming)
        return renderedSet.symmetricDifference(incomingSet)
    }

    @MainActor
    func shouldIgnoreIncomingBlocks(_ incoming: [PublishArticleBlock], in editor: EditorView) -> Bool {
        guard let pendingParentBlocks else { return false }
        let currentEditorBlocks = Self.serializeBlocks(
            from: editor.attributedText,
            previousBlocks: renderedBlocks
        )
        return currentEditorBlocks == pendingParentBlocks && incoming != pendingParentBlocks
    }

    @MainActor
    func insertPendingImagesIfNeeded(_ pendingMediaIDs: [UUID], into editor: EditorView) -> [UUID] {
        var insertedMediaIDs: [UUID] = []
        for mediaID in pendingMediaIDs where handledPendingMediaIDs.contains(mediaID) == false {
            guard let item = selectedImages.first(where: { $0.id == mediaID }) else {
                continue
            }
            insertImage(item: item, into: editor)
            handledPendingMediaIDs.insert(mediaID)
            insertedMediaIDs.append(mediaID)
        }

        handledPendingMediaIDs.formIntersection(Set(pendingMediaIDs))
        return insertedMediaIDs
    }

    @MainActor
    func insertImage(item: PublishSelectedImage, into editor: EditorView) {
        let insertionRange = preferredSelectionRange(for: editor)
        let blockID = UUID()
        let attachmentView = PublishArticleImageAttachmentView(
            blockID: blockID,
            mediaID: item.id,
            caption: "",
            selectedImage: item,
            onCaptionChange: { [weak self] blockID, caption in
                self?.updateCaption(blockID: blockID, caption: caption)
            },
            onReplace: { [weak self] blockID in
                self?.parent.onReplaceImageBlock(blockID)
            },
            onDelete: { [weak self] blockID in
                self?.parent.onRemoveImageBlock(blockID)
            }
        )
        let attachment = Attachment(attachmentView, size: .fullWidth)
        attachment.selectBeforeDelete = true
        markNextCommittedTextChangeAsProgrammatic()

        let attributedText = editor.attributedText
        let safeLocation = max(0, min(insertionRange.location, attributedText.length))
        let safeLength = max(0, min(insertionRange.length, attributedText.length - safeLocation))
        let characterBefore = safeLocation > 0
            ? attributedText.attributedSubstring(from: NSRange(location: safeLocation - 1, length: 1)).string
            : nil
        let characterAtInsertion = safeLocation < attributedText.length
            ? attributedText.attributedSubstring(from: NSRange(location: safeLocation, length: 1)).string
            : nil

        let hasLeadingSeparator = characterBefore == "\n"
        let hasTrailingSeparator = characterAtInsertion == "\n"
        let replacementRange = NSRange(
            location: safeLocation,
            length: hasTrailingSeparator ? max(1, safeLength) : safeLength
        )

        let insertedContent = NSMutableAttributedString()
        if hasLeadingSeparator == false, safeLocation > 0 {
            insertedContent.append(NSAttributedString(string: "\n"))
        }
        insertedContent.append(attachment.string)
        insertedContent.append(NSAttributedString(string: "\n"))

        editor.replaceCharacters(in: replacementRange, with: insertedContent)
        let nextSelectionLocation = min(
            replacementRange.location + insertedContent.length,
            editor.attributedText.length
        )
        let nextSelection = NSRange(location: nextSelectionLocation, length: 0)
        lastKnownSelectionRange = nextSelection
        editor.setFocus(at: nextSelection)
        scheduleSyncBlocks(from: editor)
    }

    @MainActor
    func insertTopic(into editor: EditorView) {
        let shouldRestoreFocus = editor.isFirstResponder == false
        let attributedText = NSMutableAttributedString(attributedString: editor.attributedText)
        let selectedRange = editor.selectedRange
        attributedText.replaceCharacters(in: selectedRange, with: "")
        let insertedRange = PublishTopicTokenController.insertTopicMarker(
            in: attributedText,
            at: selectedRange.location
        )
        activeTopicAnchorLocation = insertedRange.location

        isApplyingBlocks = true
        markNextCommittedTextChangeAsProgrammatic()
        editor.attributedText = attributedText
        editor.selectedRange = NSRange(
            location: insertedRange.location + insertedRange.length,
            length: 0
        )
        isApplyingBlocks = false
        if shouldRestoreFocus {
            editor.becomeFirstResponder()
        }
        scheduleSyncBlocks(from: editor)
    }

    @MainActor
    func insertMention(
        _ mentionText: String,
        into editor: EditorView
    ) {
        let shouldRestoreFocus = editor.isFirstResponder == false
        let selectionRange = preferredSelectionRange(for: editor)

        isApplyingBlocks = true
        markNextCommittedTextChangeAsProgrammatic()
        editor.replaceCharacters(in: selectionRange, with: mentionText)
        let insertionLength = (mentionText as NSString).length
        let nextRange = NSRange(
            location: min(selectionRange.location + insertionLength, editor.attributedText.length),
            length: 0
        )
        lastKnownSelectionRange = nextRange
        editor.selectedRange = nextRange
        isApplyingBlocks = false
        if shouldRestoreFocus {
            editor.becomeFirstResponder()
        }
        scheduleSyncBlocks(from: editor)
    }

    @MainActor
    func updateHeight(from editor: EditorView) {
        editor.layoutIfNeeded()
        let fittingWidth = editor.bounds.width
        guard fittingWidth > 0 else {
            return
        }
        let fittingSize = editor.sizeThatFits(
            CGSize(width: fittingWidth, height: .greatestFiniteMagnitude)
        )
        let measuredHeight = max(240, fittingSize.height)
        guard abs(parent.editorHeight - measuredHeight) > 1 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.parent.editorHeight = measuredHeight
        }
    }

    @MainActor
    func preferredSelectionRange(for editor: EditorView) -> NSRange {
        let range = editor.selectedRange
        if range.location != NSNotFound {
            return range
        }
        return lastKnownSelectionRange
    }

    @MainActor
    func restoreSelection(on editor: EditorView, preferredRange: NSRange, shouldFocus: Bool) {
        let clampedLocation = min(preferredRange.location, editor.attributedText.length)
        let clampedRange = NSRange(location: clampedLocation, length: 0)
        lastKnownSelectionRange = clampedRange
        editor.selectedRange = clampedRange
        if shouldFocus {
            editor.becomeFirstResponder()
        }
    }

    @MainActor
    func scheduleSyncBlocks(from editor: EditorView) {
        scheduledSyncToken += 1
        let token = scheduledSyncToken
        let expectedText = editor.attributedText.string
        DispatchQueue.main.async { [weak self, weak editor] in
            guard let self, let editor else { return }
            guard self.scheduledSyncToken == token else {
                return
            }
            guard editor.attributedText.string == expectedText else {
                return
            }
            self.syncBlocks(from: editor)
        }
    }

    @MainActor
    func markNextCommittedTextChangeAsProgrammatic() {
        ignoredCommittedTextChangeCount += 1
    }
}
