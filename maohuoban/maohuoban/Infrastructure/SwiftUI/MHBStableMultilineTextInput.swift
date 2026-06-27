import SwiftUI
import UIKit

// MHBStableMultilineTextInput 稳定多行文本输入
// 核心职责：
// - 使用 UITextView 承载多行输入、光标和输入法组合态
// - 将稳定文本变化、动态高度和显式焦点状态同步到 SwiftUI Binding
struct MHBStableMultilineTextInput: UIViewRepresentable {
    @Binding private var text: String
    @Binding private var isFocused: Bool
    @Binding private var dynamicHeight: CGFloat
    private let font: UIFont
    private let textColor: UIColor
    private let placeholder: String
    private let placeholderColor: UIColor
    private let tintColor: UIColor
    private let minHeight: CGFloat
    private let maxHeight: CGFloat
    private let keyboardDismissMode: UIScrollView.KeyboardDismissMode
    private let allowsFirstResponder: Bool

    init(
        text: Binding<String>,
        isFocused: Binding<Bool>,
        dynamicHeight: Binding<CGFloat>,
        font: UIFont,
        textColor: UIColor,
        placeholder: String,
        placeholderColor: UIColor,
        tintColor: UIColor,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        keyboardDismissMode: UIScrollView.KeyboardDismissMode = .none,
        allowsFirstResponder: Bool = true
    ) {
        _text = text
        _isFocused = isFocused
        _dynamicHeight = dynamicHeight
        self.font = font
        self.textColor = textColor
        self.placeholder = placeholder
        self.placeholderColor = placeholderColor
        self.tintColor = tintColor
        self.minHeight = minHeight
        self.maxHeight = max(maxHeight, minHeight)
        self.keyboardDismissMode = keyboardDismissMode
        self.allowsFirstResponder = allowsFirstResponder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isFocused: $isFocused,
            dynamicHeight: $dynamicHeight,
            minHeight: minHeight,
            maxHeight: maxHeight
        )
    }

    func makeUIView(context: Context) -> StableTextView {
        let textView = StableTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = font
        textView.textColor = textColor
        textView.tintColor = tintColor
        textView.isScrollEnabled = false
        textView.alwaysBounceVertical = false
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.spellCheckingType = .yes
        textView.keyboardDismissMode = keyboardDismissMode
        textView.allowsFirstResponder = allowsFirstResponder
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = Self.textContainerInset(
            font: font,
            minHeight: minHeight
        )
        textView.textContainer.widthTracksTextView = true
        textView.typingAttributes[.font] = font
        textView.typingAttributes[.foregroundColor] = textColor
        textView.applyPlaceholder(
            placeholder,
            font: font,
            color: placeholderColor
        )
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.updateHeightIfNeeded(for: textView, force: true)
        context.coordinator.syncFocusIfNeeded(
            for: textView,
            shouldBeFocused: isFocused,
            allowsFirstResponder: allowsFirstResponder
        )
        return textView
    }

    func updateUIView(_ uiView: StableTextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        context.coordinator.dynamicHeight = $dynamicHeight
        uiView.font = font
        uiView.textColor = textColor
        uiView.textContainerInset = Self.textContainerInset(
            font: font,
            minHeight: minHeight
        )
        uiView.textContainer.widthTracksTextView = true
        uiView.typingAttributes[.font] = font
        uiView.typingAttributes[.foregroundColor] = textColor
        uiView.keyboardDismissMode = keyboardDismissMode
        uiView.allowsFirstResponder = allowsFirstResponder
        if !allowsFirstResponder,
           uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
        uiView.applyPlaceholder(
            placeholder,
            font: font,
            color: placeholderColor
        )
        uiView.tintColor = tintColor
        uiView.updatePlaceholderVisibility()
        context.coordinator.updateHeightIfNeeded(for: uiView)
        context.coordinator.syncFocusIfNeeded(
            for: uiView,
            shouldBeFocused: isFocused,
            allowsFirstResponder: allowsFirstResponder
        )

        guard uiView.text != text,
              !uiView.hasMarkedText
        else {
            return
        }

        context.coordinator.isApplyingSwiftUIText = true
        uiView.text = text
        uiView.updatePlaceholderVisibility()
        context.coordinator.updateHeightIfNeeded(for: uiView, force: true)
        context.coordinator.isApplyingSwiftUIText = false
    }

    private static func textContainerInset(
        font: UIFont,
        minHeight: CGFloat
    ) -> UIEdgeInsets {
        let verticalInset = max((minHeight - font.lineHeight) / 2, 0)
        return UIEdgeInsets(
            top: verticalInset,
            left: 0,
            bottom: verticalInset,
            right: 0
        )
    }

    // Coordinator UITextView 文本同步协调器
    // 核心职责：
    // - 过滤 SwiftUI 主动回写造成的重复通知
    // - 避免输入法组合态下的异常空文本覆盖已有业务草稿
    // - 仅在焦点 Binding 翻转时驱动 first responder 变化
    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        var dynamicHeight: Binding<CGFloat>
        var isApplyingSwiftUIText = false
        private var wasComposing = false
        private let minHeight: CGFloat
        private let maxHeight: CGFloat
        private var lastFocusBindingValue: Bool
        private var pendingHeightValue: CGFloat?
        private var isHeightCommitScheduled = false

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            dynamicHeight: Binding<CGFloat>,
            minHeight: CGFloat,
            maxHeight: CGFloat
        ) {
            self.text = text
            self.isFocused = isFocused
            self.dynamicHeight = dynamicHeight
            self.minHeight = minHeight
            self.maxHeight = maxHeight
            self.lastFocusBindingValue = isFocused.wrappedValue
        }

        func textViewDidChange(_ textView: UITextView) {
            let newValue = textView.text ?? ""
            let hasMarkedText = textView.hasMarkedText
            if let stableTextView = textView as? StableTextView {
                stableTextView.updatePlaceholderVisibility()
            }
            updateHeightIfNeeded(for: textView, force: true)

            guard !isApplyingSwiftUIText,
                  text.wrappedValue != newValue
            else {
                return
            }

            if hasMarkedText {
                wasComposing = true
                return
            }

            if wasComposing,
               newValue.isEmpty {
                wasComposing = false
                return
            }

            wasComposing = false
            text.wrappedValue = newValue
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard (textView as? StableTextView)?.allowsFirstResponder != false else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self,
                      !self.isFocused.wrappedValue
                else {
                    return
                }

                self.isFocused.wrappedValue = true
                self.lastFocusBindingValue = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.isFocused.wrappedValue
                else {
                    return
                }

                self.isFocused.wrappedValue = false
                self.lastFocusBindingValue = false
            }
        }

        func syncFocusIfNeeded(
            for textView: UITextView,
            shouldBeFocused: Bool,
            allowsFirstResponder: Bool
        ) {
            let focusBindingDidChange = shouldBeFocused != lastFocusBindingValue
            guard focusBindingDidChange
                    || shouldBeFocused && allowsFirstResponder && !textView.isFirstResponder
            else {
                return
            }

            if shouldBeFocused,
               !allowsFirstResponder {
                return
            }

            lastFocusBindingValue = shouldBeFocused

            if shouldBeFocused {
                guard !textView.isFirstResponder else {
                    return
                }

                DispatchQueue.main.async { [weak textView] in
                    guard let textView else {
                        return
                    }

                    textView.becomeFirstResponder()
                }
            } else {
                guard textView.isFirstResponder else {
                    return
                }

                DispatchQueue.main.async { [weak textView] in
                    guard let textView else {
                        return
                    }

                    textView.resignFirstResponder()
                }
            }
        }

        func updateHeightIfNeeded(
            for textView: UITextView,
            force: Bool = false
        ) {
            textView.layoutIfNeeded()
            let width = max(textView.bounds.width, textView.textContainer.size.width, 1)
            let fittingSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            let measuredHeight = textView.sizeThatFits(fittingSize).height
            let shouldScroll = measuredHeight > maxHeight + 0.5
            if textView.isScrollEnabled != shouldScroll {
                textView.isScrollEnabled = shouldScroll
                textView.alwaysBounceVertical = shouldScroll
                textView.showsVerticalScrollIndicator = shouldScroll
                textView.invalidateIntrinsicContentSize()
            }

            let clampedHeight = min(max(measuredHeight, minHeight), maxHeight)
            normalizeViewport(in: textView, shouldScroll: shouldScroll)
            guard force || abs(dynamicHeight.wrappedValue - clampedHeight) > 0.5 else {
                return
            }

            scheduleHeightCommit(clampedHeight)
        }

        private func normalizeViewport(
            in textView: UITextView,
            shouldScroll: Bool
        ) {
            let adjustedInset = textView.adjustedContentInset
            let minOffset = CGPoint(
                x: -adjustedInset.left,
                y: -adjustedInset.top
            )

            guard shouldScroll else {
                guard
                    abs(textView.contentOffset.x - minOffset.x) > 0.5
                        || abs(textView.contentOffset.y - minOffset.y) > 0.5
                else {
                    return
                }

                textView.setContentOffset(minOffset, animated: false)
                return
            }

            let maxYOffset = max(
                minOffset.y,
                textView.contentSize.height - textView.bounds.height + adjustedInset.bottom
            )
            let clampedOffset = CGPoint(
                x: minOffset.x,
                y: min(max(textView.contentOffset.y, minOffset.y), maxYOffset)
            )

            guard
                abs(textView.contentOffset.x - clampedOffset.x) > 0.5
                    || abs(textView.contentOffset.y - clampedOffset.y) > 0.5
            else {
                return
            }

            textView.setContentOffset(clampedOffset, animated: false)
        }

        private func scheduleHeightCommit(_ height: CGFloat) {
            pendingHeightValue = height
            guard !isHeightCommitScheduled else {
                return
            }

            isHeightCommitScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                self.isHeightCommitScheduled = false
                guard let pendingHeightValue = self.pendingHeightValue else {
                    return
                }
                self.pendingHeightValue = nil

                if abs(self.dynamicHeight.wrappedValue - pendingHeightValue) > 0.5 {
                    self.dynamicHeight.wrappedValue = pendingHeightValue
                }
            }
        }
    }

    // StableTextView 稳定多行输入 UIKit 视图
    // 核心职责：
    // - 将占位文字放入 UITextView 坐标系内对齐光标
    // - 根据真实可见文本控制占位文字显隐
    @MainActor
    final class StableTextView: UITextView {
        private let placeholderLabel = UILabel()
        var allowsFirstResponder = true

        override init(frame: CGRect, textContainer: NSTextContainer?) {
            super.init(frame: frame, textContainer: textContainer)
            configurePlaceholderLabel()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            normalizeContentOffsetIfNeeded()
            updatePlaceholderFrame()
        }

        override var canBecomeFirstResponder: Bool {
            allowsFirstResponder && super.canBecomeFirstResponder
        }

        override func becomeFirstResponder() -> Bool {
            guard allowsFirstResponder else {
                return false
            }

            return super.becomeFirstResponder()
        }

        override var intrinsicContentSize: CGSize {
            CGSize(
                width: UIView.noIntrinsicMetric,
                height: super.intrinsicContentSize.height
            )
        }

        func applyPlaceholder(
            _ placeholder: String,
            font: UIFont,
            color: UIColor
        ) {
            placeholderLabel.text = placeholder
            placeholderLabel.font = font
            placeholderLabel.textColor = color
            updatePlaceholderFrame()
            updatePlaceholderVisibility()
        }

        func updatePlaceholderVisibility() {
            placeholderLabel.isHidden = !text.isEmpty
        }

        private func configurePlaceholderLabel() {
            placeholderLabel.numberOfLines = 1
            placeholderLabel.isUserInteractionEnabled = false
            addSubview(placeholderLabel)
        }

        private func updatePlaceholderFrame() {
            let inset = textContainerInset
            let x = inset.left + textContainer.lineFragmentPadding
            let y = inset.top
            let width = max(bounds.width - x - inset.right, 0)
            let height = placeholderLabel.intrinsicContentSize.height
            placeholderLabel.frame = CGRect(
                x: x,
                y: y,
                width: width,
                height: height
            )
        }

        private func normalizeContentOffsetIfNeeded() {
            guard !isScrollEnabled else {
                return
            }

            let pinnedOffset = CGPoint(
                x: -adjustedContentInset.left,
                y: -adjustedContentInset.top
            )
            guard
                abs(contentOffset.x - pinnedOffset.x) > 0.5
                    || abs(contentOffset.y - pinnedOffset.y) > 0.5
            else {
                return
            }

            contentOffset = pinnedOffset
        }
    }
}

private extension UITextView {
    var hasMarkedText: Bool {
        guard let markedTextRange else {
            return false
        }
        return !markedTextRange.isEmpty
    }
}
