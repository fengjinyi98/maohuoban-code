import SwiftUI
import UIKit

extension MHBStableMultilineTextInput {
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
}

extension UITextView {
    var hasMarkedText: Bool {
        guard let markedTextRange else {
            return false
        }
        return !markedTextRange.isEmpty
    }
}
