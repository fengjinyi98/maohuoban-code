import UIKit

extension MHBStableMultilineTextInput {
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
