import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishTopicTextEditor 发布正文话题输入器
// 核心职责：
// - 承载正文输入、占位提示和自适应高度
// - 支持发布页工具栏触发的井号话题与用户提及插入
// - 将正文中识别到的话题同步为结构化草稿字段
struct PublishTopicTextEditor: UIViewRepresentable {
    @Binding var text: String

    let placeholder: String
    let minHeight: CGFloat
    let pendingTopicInsertionNonce: Int
    let pendingMentionInsertionNonce: Int
    let pendingMentionInsertionText: String?
    let onPendingTopicInsertionHandled: () -> Void
    let onPendingMentionInsertionHandled: () -> Void
    let onTopicsChange: ([String]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PublishPlaceholderTextView {
        let textView = PublishPlaceholderTextView()
        textView.delegate = context.coordinator
        textView.font = Self.textFont
        textView.textColor = MHBTheme.ColorToken.labelPrimary.publishUIKitColor
        textView.tintColor = MHBTheme.ColorToken.primary.publishUIKitColor
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.placeholder = placeholder
        textView.placeholderColor = MHBTheme.ColorToken.labelTertiary.publishUIKitColor
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        context.coordinator.applyPlainText(text, to: textView)
        return textView
    }

    func updateUIView(_ uiView: PublishPlaceholderTextView, context: Context) {
        context.coordinator.parent = self
        uiView.font = Self.textFont
        uiView.textColor = MHBTheme.ColorToken.labelPrimary.publishUIKitColor
        uiView.tintColor = MHBTheme.ColorToken.primary.publishUIKitColor
        uiView.placeholder = placeholder
        uiView.placeholderColor = MHBTheme.ColorToken.labelTertiary.publishUIKitColor

        if uiView.markedTextRange != nil {
            return
        }

        if pendingTopicInsertionNonce > context.coordinator.lastHandledPendingTopicInsertionNonce {
            context.coordinator.insertTopicMarker(into: uiView)
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

        if context.coordinator.isProgrammaticChange == false,
           uiView.attributedText.string != text {
            context.coordinator.applyPlainText(text, to: uiView)
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: PublishPlaceholderTextView,
        context: Context
    ) -> CGSize? {
        let fallbackWidth = uiView.bounds.width > 0 ? uiView.bounds.width : 320
        let targetWidth = proposal.width ?? fallbackWidth
        let measuredSize = uiView.sizeThatFits(
            CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: targetWidth, height: max(minHeight, measuredSize.height))
    }

    static var textFont: UIFont {
        UIFont.systemFont(ofSize: 15, weight: .regular)
    }

    final class Coordinator: NSObject, UITextViewDelegate, @unchecked Sendable {
        var parent: PublishTopicTextEditor
        var lastHandledPendingTopicInsertionNonce: Int
        var lastHandledPendingMentionInsertionNonce: Int
        var activeTopicAnchorLocation: Int?
        var isProgrammaticChange = false

        private var commitSyncGate = PublishCommittedTextSyncGate()

        init(parent: PublishTopicTextEditor) {
            self.parent = parent
            self.lastHandledPendingTopicInsertionNonce = parent.pendingTopicInsertionNonce
            self.lastHandledPendingMentionInsertionNonce = parent.pendingMentionInsertionNonce
        }

        @MainActor
        func applyPlainText(
            _ text: String,
            to textView: PublishPlaceholderTextView
        ) {
            let attributedText = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: PublishTopicTextEditor.textFont,
                    .foregroundColor: MHBTheme.ColorToken.labelPrimary.publishUIKitColor,
                ]
            )

            _ = PublishTopicTokenController.reconcileTopics(
                in: attributedText,
                defaultColor: MHBTheme.ColorToken.labelPrimary.publishUIKitColor
            )
            activeTopicAnchorLocation = nil

            isProgrammaticChange = true
            textView.attributedText = attributedText
            textView.selectedRange = NSRange(
                location: min(textView.selectedRange.location, attributedText.length),
                length: 0
            )
            isProgrammaticChange = false
            textView.updatePlaceholderVisibility()
        }

        @MainActor
        func insertTopicMarker(into textView: PublishPlaceholderTextView) {
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            let selectedRange = textView.selectedRange
            let safeLocation = max(0, min(selectedRange.location, attributedText.length))
            let safeRange = NSRange(
                location: safeLocation,
                length: max(0, min(selectedRange.length, attributedText.length - safeLocation))
            )
            attributedText.replaceCharacters(in: safeRange, with: "")
            let insertedRange = PublishTopicTokenController.insertTopicMarker(
                in: attributedText,
                at: safeRange.location
            )
            activeTopicAnchorLocation = insertedRange.location
            applyAttributedText(
                attributedText,
                selectedRange: NSRange(location: insertedRange.location + insertedRange.length, length: 0),
                to: textView
            )
            textView.becomeFirstResponder()
            syncState(from: textView)
        }

        @MainActor
        func insertMention(
            _ mentionText: String,
            into textView: PublishPlaceholderTextView
        ) {
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            let selectedRange = textView.selectedRange
            let safeLocation = max(0, min(selectedRange.location, attributedText.length))
            let safeRange = NSRange(
                location: safeLocation,
                length: max(0, min(selectedRange.length, attributedText.length - safeLocation))
            )
            attributedText.replaceCharacters(in: safeRange, with: mentionText)
            let insertionLength = (mentionText as NSString).length
            applyAttributedText(
                attributedText,
                selectedRange: NSRange(location: safeRange.location + insertionLength, length: 0),
                to: textView
            )
            textView.becomeFirstResponder()
            syncState(from: textView)
        }

        @MainActor
        private func syncState(from textView: PublishPlaceholderTextView) {
            if textView.markedTextRange != nil {
                parent.text = textView.text
                return
            }

            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            let reconcileResult = PublishTopicTokenController.reconcileTopics(
                in: attributedText,
                defaultColor: MHBTheme.ColorToken.labelPrimary.publishUIKitColor
            )
            activeTopicAnchorLocation = reconcileResult.activeAnchorLocation

            let currentSelection = textView.selectedRange
            applyAttributedText(
                attributedText,
                selectedRange: NSRange(
                    location: min(currentSelection.location, attributedText.length),
                    length: 0
                ),
                to: textView
            )

            parent.text = attributedText.string
            parent.onTopicsChange(reconcileResult.topicNames)
        }

        @MainActor
        private func applyAttributedText(
            _ attributedText: NSAttributedString,
            selectedRange: NSRange,
            to textView: PublishPlaceholderTextView
        ) {
            isProgrammaticChange = true
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            isProgrammaticChange = false
            textView.updatePlaceholderVisibility()
        }

        @MainActor
        private func updateSelection(
            _ selectedRange: NSRange,
            in textView: PublishPlaceholderTextView
        ) {
            isProgrammaticChange = true
            textView.selectedRange = selectedRange
            isProgrammaticChange = false
        }

        @MainActor
        private func deleteTopicToken(
            in textView: PublishPlaceholderTextView,
            affectedRange: NSRange
        ) -> Bool {
            guard let topicRange = PublishTopicTokenController.topicTokenRangeForDeletion(
                in: textView.attributedText,
                affectedRange: affectedRange
            ) else {
                return false
            }

            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            attributedText.replaceCharacters(in: topicRange, with: "")
            applyAttributedText(
                attributedText,
                selectedRange: NSRange(location: min(topicRange.location, attributedText.length), length: 0),
                to: textView
            )
            syncState(from: textView)
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let textView = textView as? PublishPlaceholderTextView,
                  isProgrammaticChange == false else { return }
            if textView.markedTextRange != nil {
                parent.text = textView.text
                return
            }
            let committedText = textView.text ?? ""
            let scheduledSnapshot = commitSyncGate.recordCommittedSnapshot(committedText)
            Task { @MainActor [weak self, weak textView] in
                guard let self, let textView else { return }
                await Task.yield()
                let currentText = textView.text ?? ""
                let isMarked = textView.markedTextRange != nil
                guard self.commitSyncGate.shouldApply(
                    scheduledSnapshot: scheduledSnapshot,
                    currentText: currentText,
                    isMarked: isMarked
                ) else {
                    return
                }
                self.commitSyncGate.finish(scheduledSnapshot: scheduledSnapshot)
                self.syncState(from: textView)
            }
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard let textView = textView as? PublishPlaceholderTextView else { return true }
            guard text.isEmpty else { return true }
            return deleteTopicToken(in: textView, affectedRange: range) == false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let textView = textView as? PublishPlaceholderTextView,
                  isProgrammaticChange == false,
                  textView.markedTextRange == nil,
                  textView.selectedRange.length == 0,
                  let topicRange = PublishTopicTokenController.topicTokenRangeForTap(
                    in: textView.attributedText,
                    location: textView.selectedRange.location
                  ) else { return }

            let targetLocation = topicRange.location + topicRange.length
            if textView.selectedRange.location != targetLocation {
                updateSelection(
                    NSRange(location: targetLocation, length: 0),
                    in: textView
                )
            }
            textView.becomeFirstResponder()
        }
    }
}

// PublishPlaceholderTextView 发布正文占位输入框
// 核心职责：
// - 为发布正文编辑器提供 UITextView 占位态
// - 让 UIKit 输入桥接保持 SwiftUI 编辑器的视觉语义
@MainActor
final class PublishPlaceholderTextView: UITextView {
    var placeholder: String = "" {
        didSet {
            placeholderLabel.text = placeholder
        }
    }

    var placeholderColor: UIColor = .tertiaryLabel {
        didSet {
            placeholderLabel.textColor = placeholderColor
        }
    }

    private let placeholderLabel = UILabel()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupPlaceholder()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPlaceholder() {
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = PublishTopicTextEditor.textFont
        placeholderLabel.textColor = placeholderColor
        placeholderLabel.numberOfLines = 0
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])

        updatePlaceholderVisibility()
    }

    func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = attributedText.length > 0
    }
}
