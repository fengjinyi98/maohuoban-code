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
}
