import Foundation
import Proton
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishArticleBlock 图文编辑块
// 核心职责：
// - 承接图文页的文本块与图片块顺序
// - 为富文本编辑器和发布草稿同步提供稳定本地真值
struct PublishArticleBlock: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case text
        case image
    }

    let id: UUID
    var kind: Kind
    var text: String
    var mediaID: UUID?

    init(
        id: UUID = UUID(),
        kind: Kind = .text,
        text: String = "",
        mediaID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.mediaID = mediaID
    }

    var isImage: Bool {
        kind == .image
    }
}

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
    let onPendingInsertionHandled: ([UUID]) -> Void
    let onPendingTopicInsertionHandled: () -> Void
    let onPendingMentionInsertionHandled: () -> Void
    let onTopicsChange: ([String]) -> Void
    let onRemoveImageBlock: (UUID) -> Void
    let onReplaceImageBlock: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
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
            context.coordinator.insertMention(into: uiView)
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

    final class Coordinator: NSObject, EditorViewDelegate, @unchecked Sendable {
        var parent: PublishArticleRichTextEditor
        var renderedBlocks: [PublishArticleBlock] = []
        var renderedMediaIDs: [UUID] = []
        var lastHandledPendingTopicInsertionNonce: Int
        var lastHandledPendingMentionInsertionNonce: Int
        var selectedImages: [PublishSelectedImage] = []
        var pendingParentBlocks: [PublishArticleBlock]?

        private var handledPendingMediaIDs = Set<UUID>()
        private var isApplyingBlocks = false
        private var activeTopicAnchorLocation: Int?
        private var lastKnownSelectionRange = NSRange(location: 0, length: 0)
        private var commitSyncGate = PublishCommittedTextSyncGate()
        private var ignoredCommittedTextChangeCount = 0
        private var scheduledSyncToken = 0
        private var scheduledSelectionSyncToken = 0

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
        func insertMention(into editor: EditorView) {
            let shouldRestoreFocus = editor.isFirstResponder == false
            let selectionRange = preferredSelectionRange(for: editor)

            isApplyingBlocks = true
            markNextCommittedTextChangeAsProgrammatic()
            editor.replaceCharacters(in: selectionRange, with: "@")
            let nextRange = NSRange(
                location: min(selectionRange.location + 1, editor.attributedText.length),
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
        private func deleteTopicToken(in editor: EditorView, selectionRange: NSRange) {
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
        private func updateCaption(blockID: UUID, caption: String) {
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
        private func syncBlocks(from editor: EditorView) {
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
        private func preferredSelectionRange(for editor: EditorView) -> NSRange {
            let range = editor.selectedRange
            if range.location != NSNotFound {
                return range
            }
            return lastKnownSelectionRange
        }

        @MainActor
        private func restoreSelection(on editor: EditorView, preferredRange: NSRange, shouldFocus: Bool) {
            let clampedLocation = min(preferredRange.location, editor.attributedText.length)
            let clampedRange = NSRange(location: clampedLocation, length: 0)
            lastKnownSelectionRange = clampedRange
            editor.selectedRange = clampedRange
            if shouldFocus {
                editor.becomeFirstResponder()
            }
        }

        @MainActor
        private func scheduleSyncBlocks(from editor: EditorView) {
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
        private func markNextCommittedTextChangeAsProgrammatic() {
            ignoredCommittedTextChangeCount += 1
        }

        @MainActor
        private func scheduleTopicSyncIfNeeded(from editor: EditorView) {
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
}

// PublishArticleImageAttachmentView 图文图片附件视图
// 核心职责：
// - 作为 Proton block attachment 渲染本地图片和图片说明
// - 为删除、替换和图注编辑提供独立交互入口
@MainActor
final class PublishArticleImageAttachmentView: UIView, AttachmentViewIdentifying, UITextFieldDelegate {
    let blockID: UUID
    private(set) var mediaID: UUID
    private(set) var selectedImage: PublishSelectedImage

    var caption: String {
        captionField.text ?? ""
    }

    nonisolated var name: EditorContent.Name {
        EditorContent.Name("maohuoban.publish.article.image")
    }

    nonisolated var type: AttachmentType {
        .block
    }

    private let onCaptionChange: (UUID, String) -> Void
    private let onReplace: (UUID) -> Void
    private let onDelete: (UUID) -> Void
    private let imageView = UIImageView()
    private let replaceButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let captionField = UITextField()

    init(
        blockID: UUID,
        mediaID: UUID,
        caption: String,
        selectedImage: PublishSelectedImage,
        onCaptionChange: @escaping (UUID, String) -> Void,
        onReplace: @escaping (UUID) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        self.blockID = blockID
        self.mediaID = mediaID
        self.selectedImage = selectedImage
        self.onCaptionChange = onCaptionChange
        self.onReplace = onReplace
        self.onDelete = onDelete
        super.init(frame: .zero)
        setup()
        captionField.text = caption
        imageView.image = selectedImage.image
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateItem(_ selectedImage: PublishSelectedImage) {
        guard self.mediaID != selectedImage.id || imageView.image !== selectedImage.image else {
            return
        }
        self.mediaID = selectedImage.id
        self.selectedImage = selectedImage
        imageView.image = selectedImage.image
    }

    private func setup() {
        backgroundColor = .clear

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = MHBTheme.Radius.medium
        addSubview(imageView)

        replaceButton.translatesAutoresizingMaskIntoConstraints = false
        replaceButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath"), for: .normal)
        replaceButton.tintColor = .white
        replaceButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        replaceButton.layer.cornerRadius = 14
        replaceButton.addTarget(self, action: #selector(replaceTapped), for: .touchUpInside)
        addSubview(replaceButton)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        deleteButton.layer.cornerRadius = 14
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        addSubview(deleteButton)

        captionField.translatesAutoresizingMaskIntoConstraints = false
        captionField.placeholder = "添加图片注释"
        captionField.font = .systemFont(ofSize: 14)
        captionField.textColor = MHBTheme.ColorToken.labelSecondary.publishUIKitColor
        captionField.borderStyle = .none
        captionField.textAlignment = .center
        captionField.backgroundColor = MHBTheme.ColorToken.separatorSoft.publishUIKitColor
        captionField.layer.cornerRadius = MHBTheme.Radius.small
        captionField.layer.masksToBounds = true
        captionField.delegate = self
        captionField.addTarget(self, action: #selector(captionChanged), for: .editingChanged)
        addSubview(captionField)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 240),

            replaceButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 8),
            replaceButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            replaceButton.widthAnchor.constraint(equalToConstant: 28),
            replaceButton.heightAnchor.constraint(equalToConstant: 28),

            deleteButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -8),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28),

            captionField.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            captionField.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionField.trailingAnchor.constraint(equalTo: trailingAnchor),
            captionField.heightAnchor.constraint(equalToConstant: 40),
            captionField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    @objc private func deleteTapped() {
        onDelete(blockID)
    }

    @objc private func replaceTapped() {
        onReplace(blockID)
    }

    @objc private func captionChanged() {
        onCaptionChange(blockID, caption)
    }
}
