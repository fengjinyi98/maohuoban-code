import SwiftUI
import UIKit

// MHBStableTextField 稳定单行文本输入框
// 核心职责：
// - 基于 UIKit UITextField 承载单行输入体验
// - 过滤输入法组合态，确保业务 Binding 只接收稳定提交文本
public struct MHBStableTextField: UIViewRepresentable {
    @Binding private var text: String
    @Binding private var isComposing: Bool
    private let placeholder: String
    private let font: UIFont
    private let textColor: UIColor
    private let returnKeyType: UIReturnKeyType
    private let onSubmit: () -> Void

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isComposing: Binding<Bool> = .constant(false),
        font: UIFont = .systemFont(ofSize: 17, weight: .regular),
        textColor: UIColor = .label,
        returnKeyType: UIReturnKeyType = .done,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self._isComposing = isComposing
        self.font = font
        self.textColor = textColor
        self.returnKeyType = returnKeyType
        self.onSubmit = onSubmit
    }

    public func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.placeholder = placeholder
        textField.font = font
        textField.textColor = textColor
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.returnKeyType = returnKeyType
        textField.contentVerticalAlignment = .center
        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.required, for: .vertical)
        textField.setContentCompressionResistancePriority(.required, for: .vertical)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return textField
    }

    public func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        uiView.placeholder = isComposing ? nil : placeholder
        uiView.font = font
        uiView.textColor = textColor
        uiView.returnKeyType = returnKeyType

        if context.coordinator.stateMachine.committedText != text {
            context.coordinator.stateMachine.syncCommittedText(text)
        }

        if uiView.text != text && !uiView.hasMarkedText {
            uiView.text = text
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MHBStableTextField
        var stateMachine: MHBStableTextInputStateMachine

        init(parent: MHBStableTextField) {
            self.parent = parent
            self.stateMachine = MHBStableTextInputStateMachine(committedText: parent.text)
        }

        @objc func editingChanged(_ textField: UITextField) {
            commitIfStable(textField)
        }

        public func textFieldDidChangeSelection(_ textField: UITextField) {
            commitIfStable(textField)
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            guard !textField.hasMarkedText else {
                commitIfStable(textField)
                return
            }
            let result = stateMachine.forceCommit(text: textField.text ?? "")
            apply(result)
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            guard !textField.hasMarkedText else {
                commitIfStable(textField)
                return false
            }
            let result = stateMachine.forceCommit(text: textField.text ?? "")
            apply(result)
            parent.onSubmit()
            return false
        }

        private func commitIfStable(_ textField: UITextField) {
            let result = stateMachine.receive(
                text: textField.text ?? "",
                hasMarkedText: textField.hasMarkedText
            )
            updatePlaceholder(for: textField, isComposing: result.isComposing)
            apply(result)
        }

        private func apply(_ result: MHBStableTextInputCommitResult) {
            if let committedText = result.committedText {
                parent.text = committedText
            }
            parent.isComposing = result.isComposing
        }

        private func updatePlaceholder(for textField: UITextField, isComposing: Bool) {
            textField.placeholder = isComposing ? nil : parent.placeholder
        }
    }
}

private extension UITextField {
    var hasMarkedText: Bool {
        markedTextRange != nil
    }
}
