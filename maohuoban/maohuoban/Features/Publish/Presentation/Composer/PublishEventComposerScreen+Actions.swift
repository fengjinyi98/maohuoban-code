import SwiftUI
import UIKit

// PublishEventComposerScreen 发布页面操作处理
// 核心职责：
// - 管理媒体选择、话题插入、用户提及等交互逻辑
// - 处理草稿准备、正文同步和数组状态维护
extension PublishEventComposerScreen {
    func openMediaPicker() {
        replacingArticleBlockID = nil
        guard selectedImages.count < PublishComposerLimits.maxImageCount else {
            return
        }
        isMediaPickerPresented = true
    }

    func handleMediaPickerResult(_ result: MHBMediaPickerResult) {
        isMediaPickerPresented = false
        if let replacingArticleBlockID {
            handleArticleImageReplacement(
                blockID: replacingArticleBlockID,
                image: result.images.first
            )
            return
        }

        let remainingCount = max(0, PublishComposerLimits.maxImageCount - selectedImages.count)
        let newImages = result.images
            .prefix(remainingCount)
            .map { PublishSelectedImage(image: $0) }
        selectedImages.append(contentsOf: newImages)
        if composerMode == .richText {
            pendingInsertedArticleMediaIDs.append(contentsOf: newImages.map(\.id))
        }
        store.updateMediaCount(selectedImages.count)
    }

    func removeImage(_ id: UUID) {
        selectedImages.removeAll { $0.id == id }
        articleBlocks.removeAll { $0.mediaID == id }
        pendingInsertedArticleMediaIDs.removeAll { $0 == id }
        store.updateMediaCount(selectedImages.count)
    }

    func removeArticleImageBlock(_ blockID: UUID) {
        guard let block = articleBlocks.first(where: { $0.id == blockID }) else { return }
        articleBlocks.removeAll { $0.id == blockID }
        if let mediaID = block.mediaID {
            selectedImages.removeAll { $0.id == mediaID }
            pendingInsertedArticleMediaIDs.removeAll { $0 == mediaID }
        }
        store.updateMediaCount(selectedImages.count)
    }

    func replaceArticleImageBlock(_ blockID: UUID) {
        replacingArticleBlockID = blockID
        isMediaPickerPresented = true
    }

    func handleArticleImageReplacement(blockID: UUID, image: UIImage?) {
        defer {
            replacingArticleBlockID = nil
            store.updateMediaCount(selectedImages.count)
        }
        guard let image,
              let blockIndex = articleBlocks.firstIndex(where: { $0.id == blockID })
        else {
            return
        }

        let previousMediaID = articleBlocks[blockIndex].mediaID
        let replacement = PublishSelectedImage(image: image)
        if let previousMediaID,
           let imageIndex = selectedImages.firstIndex(where: { $0.id == previousMediaID }) {
            selectedImages[imageIndex] = replacement
        } else {
            selectedImages.append(replacement)
        }
        articleBlocks[blockIndex].mediaID = replacement.id
    }

    func prepareDraft() {
        store.prepareDraft()
        if store.phase == .prepared {
            onPrepared()
        }
    }

    func insertTopic() {
        pendingTopicInsertionNonce += 1
    }

    func openMentionUserPicker() {
        activeSheet = .mentionUser
    }

    func dismissKeyboard() {
        MHBKeyboardDismissal.dismissActiveKeyboard()
    }

    func insertMentions(_ users: [PublishMentionUserOption]) {
        let insertionText = users
            .map { "@\($0.name) " }
            .joined()
        guard insertionText.isEmpty == false else { return }
        pendingMentionInsertionText = insertionText
        pendingMentionInsertionNonce += 1
    }

    func handlePendingArticleMediaInsertionHandled(_ mediaIDs: [UUID]) {
        pendingInsertedArticleMediaIDs.removeAll { mediaIDs.contains($0) }
    }

    func handlePendingTopicInsertionHandled() {}

    func handlePendingMentionInsertionHandled() {
        pendingMentionInsertionText = nil
    }

    func handleTopicsChange(_ topicNames: [String]) {
        store.updateTopics(topicNames)
    }

    func appendTag(_ tag: String) {
        guard composerMode == .gallery else {
            appendTagToArticleBlocks(tag)
            store.addTopic(named: tag)
            return
        }

        let currentText = store.draft.bodyText
        if currentText.isEmpty {
            store.updateBodyText(tag + " ")
        } else if currentText.hasSuffix(" ") {
            store.updateBodyText(currentText + tag + " ")
        } else {
            store.updateBodyText(currentText + " " + tag + " ")
        }
        store.addTopic(named: tag)
    }

    func appendTagToArticleBlocks(_ tag: String) {
        if let index = articleBlocks.lastIndex(where: { $0.kind == .text }) {
            let currentText = articleBlocks[index].text
            if currentText.isEmpty {
                articleBlocks[index].text = tag + " "
            } else if currentText.hasSuffix(" ") || currentText.hasSuffix("\n") {
                articleBlocks[index].text = currentText + tag + " "
            } else {
                articleBlocks[index].text = currentText + " " + tag + " "
            }
        } else {
            articleBlocks.append(PublishArticleBlock(kind: .text, text: tag + " "))
        }
    }

    func seedArticleBlocksFromDraftIfNeeded() {
        guard articleBlocks.isEmpty else { return }

        var nextBlocks: [PublishArticleBlock] = []
        let bodyText = store.draft.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if bodyText.isEmpty == false {
            nextBlocks.append(PublishArticleBlock(kind: .text, text: bodyText))
        }

        for selectedImage in selectedImages {
            nextBlocks.append(
                PublishArticleBlock(
                    kind: .image,
                    mediaID: selectedImage.id
                )
            )
        }

        articleBlocks = nextBlocks
    }

    func syncDraftBodyTextFromArticleBlocksIfNeeded() {
        guard composerMode == .richText else { return }
        let nextBodyText = articleBlocksPlainText()
        guard store.draft.bodyText != nextBodyText else { return }
        store.updateBodyText(nextBodyText)
    }

    func articleBlocksPlainText() -> String {
        articleBlocks.compactMap { block in
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        .joined(separator: "\n")
    }
}
