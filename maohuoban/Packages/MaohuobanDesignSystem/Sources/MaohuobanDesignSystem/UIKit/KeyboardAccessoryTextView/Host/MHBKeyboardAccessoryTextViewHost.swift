import SwiftUI
import UIKit

// MHBKeyboardAccessoryTextViewHost 键盘附属文本输入宿主
// 核心职责：
// - 将真实 UITextView 放入 inputAccessoryView 层，跟随系统键盘布局和动画
// - 使用 SwiftUI 承载输入区头部和工具栏，文本输入由 UIKit 负责
public struct MHBKeyboardAccessoryTextViewHost<Header: View, Toolbar: View>: UIViewControllerRepresentable {
    @Binding private var isPresented: Bool
    @Binding private var text: String
    private let placeholder: String
    private let minTextHeight: CGFloat
    private let maxTextHeight: CGFloat
    private let font: UIFont
    private let textColor: UIColor
    private let placeholderColor: UIColor
    private let tintColor: UIColor
    private let onDismiss: () -> Void
    private let header: () -> Header
    private let toolbar: () -> Toolbar

    public init(
        isPresented: Binding<Bool>,
        text: Binding<String>,
        placeholder: String,
        minTextHeight: CGFloat,
        maxTextHeight: CGFloat,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        placeholderColor: UIColor = .placeholderText,
        tintColor: UIColor = .systemBlue,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder toolbar: @escaping () -> Toolbar
    ) {
        _isPresented = isPresented
        _text = text
        self.placeholder = placeholder
        self.minTextHeight = minTextHeight
        self.maxTextHeight = maxTextHeight
        self.font = font
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.tintColor = tintColor
        self.onDismiss = onDismiss
        self.header = header
        self.toolbar = toolbar
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            isPresented: $isPresented,
            text: $text,
            onDismiss: onDismiss
        )
    }

    public func makeUIViewController(context: Context) -> MHBKeyboardAccessoryTextViewController<Header, Toolbar> {
        MHBKeyboardAccessoryTextViewController()
    }

    public func updateUIViewController(
        _ uiViewController: MHBKeyboardAccessoryTextViewController<Header, Toolbar>,
        context: Context
    ) {
        context.coordinator.isPresented = $isPresented
        context.coordinator.text = $text
        context.coordinator.onDismiss = onDismiss
        uiViewController.update(
            isPresented: isPresented,
            text: text,
            placeholder: placeholder,
            minTextHeight: minTextHeight,
            maxTextHeight: maxTextHeight,
            font: font,
            textColor: textColor,
            placeholderColor: placeholderColor,
            tintColor: tintColor,
            header: header(),
            toolbar: toolbar(),
            onPresentationChange: context.coordinator.handlePresentationChange(_:),
            onTextChange: context.coordinator.handleTextChange(_:)
        )
    }

    public static func dismantleUIViewController(
        _ uiViewController: MHBKeyboardAccessoryTextViewController<Header, Toolbar>,
        coordinator: Coordinator
    ) {
        uiViewController.dismissAccessory()
    }

    // Coordinator SwiftUI 与 UIKit 状态同步协调器
    // 核心职责：
    // - 同步输入文本到 SwiftUI Binding
    // - 将系统键盘关闭回写为业务关闭事件
    @MainActor
    public final class Coordinator {
        var isPresented: Binding<Bool>
        var text: Binding<String>
        var onDismiss: () -> Void

        init(
            isPresented: Binding<Bool>,
            text: Binding<String>,
            onDismiss: @escaping () -> Void
        ) {
            self.isPresented = isPresented
            self.text = text
            self.onDismiss = onDismiss
        }

        func handlePresentationChange(_ isPresented: Bool) {
            guard self.isPresented.wrappedValue != isPresented else {
                return
            }

            self.isPresented.wrappedValue = isPresented
            if !isPresented {
                onDismiss()
            }
        }

        func handleTextChange(_ text: String) {
            guard self.text.wrappedValue != text else {
                return
            }

            self.text.wrappedValue = text
        }
    }
}
