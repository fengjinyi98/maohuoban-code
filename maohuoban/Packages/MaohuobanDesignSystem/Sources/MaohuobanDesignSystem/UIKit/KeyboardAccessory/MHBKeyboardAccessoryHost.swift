import SwiftUI
import UIKit

// MHBKeyboardAccessoryHost SwiftUI 键盘附属视图宿主
// 核心职责：
// - 使用 UIKit inputAccessoryView 承载 SwiftUI 输入工具区
// - 通过 Binding 控制 first responder，跟随系统键盘动画呈现和收起
public struct MHBKeyboardAccessoryHost<Accessory: View>: UIViewControllerRepresentable {
    @Binding private var isPresented: Bool
    @Binding private var text: String
    private let onDismiss: () -> Void
    private let accessory: () -> Accessory

    public init(
        isPresented: Binding<Bool>,
        text: Binding<String>,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        _isPresented = isPresented
        _text = text
        self.onDismiss = onDismiss
        self.accessory = accessory
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            isPresented: $isPresented,
            text: $text,
            onDismiss: onDismiss
        )
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        MHBKeyboardAccessoryHostingController<Accessory>()
    }

    public func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        context.coordinator.isPresented = $isPresented
        context.coordinator.text = $text
        context.coordinator.onDismiss = onDismiss

        guard let hostingController = uiViewController as? MHBKeyboardAccessoryHostingController<Accessory> else {
            return
        }

        hostingController.update(
            accessory: accessory(),
            isPresented: isPresented,
            text: text,
            onPresentationChange: context.coordinator.handlePresentationChange(_:),
            onTextChange: context.coordinator.handleTextChange(_:)
        )
    }

    public static func dismantleUIViewController(
        _ uiViewController: UIViewController,
        coordinator: Coordinator
    ) {
        (uiViewController as? MHBKeyboardAccessoryHostingController<Accessory>)?.dismissAccessory()
    }

    // Coordinator 键盘附属视图呈现状态协调器
    // 核心职责：
    // - 把 UIKit 键盘收起事件同步回 SwiftUI Binding
    // - 在外部收键盘时触发业务 onDismiss 回调
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

public extension Notification.Name {
    static let mhbKeyboardAccessoryContentDidChange = Notification.Name(
        "MHBKeyboardAccessoryContentDidChange"
    )
}
