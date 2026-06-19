import SwiftUI
import UIKit

// MHBKeyboardAccessoryTextViewController 键盘附属文本输入控制器
// 核心职责：
// - 通过启动输入源拉起键盘并安装 accessory 容器
// - 将焦点交给 accessory 内真实文本输入视图
@MainActor
public final class MHBKeyboardAccessoryTextViewController<Header: View, Toolbar: View>: UIViewController, UITextViewDelegate {
    private let starterTextView = MHBKeyboardAccessoryStarterTextView()
    private let accessoryContainer = MHBKeyboardAccessoryTextInputContainerView()
    private var isPresentationRequested = false
    private var onPresentationChange: ((Bool) -> Void)?
    private var onTextChange: ((String) -> Void)?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        installStarterTextView()
        starterTextView.delegate = self
        accessoryContainer.onTextChange = { [weak self] text in
            self?.onTextChange?(text)
        }
        accessoryContainer.onHeightChange = { [weak self] in
            self?.reloadActiveInputViews()
        }
        observeKeyboardDismissal()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func update(
        isPresented: Bool,
        text: String,
        placeholder: String,
        minTextHeight: CGFloat,
        maxTextHeight: CGFloat,
        font: UIFont,
        textColor: UIColor,
        placeholderColor: UIColor,
        tintColor: UIColor,
        header: Header,
        toolbar: Toolbar,
        onPresentationChange: @escaping (Bool) -> Void,
        onTextChange: @escaping (String) -> Void
    ) {
        let wasPresentationRequested = isPresentationRequested
        isPresentationRequested = isPresented
        self.onPresentationChange = onPresentationChange
        self.onTextChange = onTextChange
        accessoryContainer.update(
            text: text,
            placeholder: placeholder,
            minTextHeight: minTextHeight,
            maxTextHeight: maxTextHeight,
            font: font,
            textColor: textColor,
            placeholderColor: placeholderColor,
            tintColor: tintColor,
            header: header,
            toolbar: toolbar
        )
        if starterTextView.text != text {
            starterTextView.text = text
        }

        if isPresented {
            presentAccessory()
        } else if wasPresentationRequested ||
                    starterTextView.isFirstResponder {
            dismissAccessory()
        }
    }

    func dismissAccessory() {
        isPresentationRequested = false
        accessoryContainer.isPresentationActive = false
        if starterTextView.isFirstResponder {
            starterTextView.resignFirstResponder()
        } else {
            cleanupDismissedAccessory()
        }
    }

    private func installStarterTextView() {
        starterTextView.backgroundColor = .clear
        starterTextView.textColor = .clear
        starterTextView.tintColor = .clear
        starterTextView.alpha = 0.01
        starterTextView.isScrollEnabled = false
        starterTextView.autocorrectionType = .yes
        starterTextView.autocapitalizationType = .sentences
        starterTextView.spellCheckingType = .yes
        starterTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(starterTextView)
        NSLayoutConstraint.activate([
            starterTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            starterTextView.topAnchor.constraint(equalTo: view.topAnchor),
            starterTextView.widthAnchor.constraint(equalToConstant: 1),
            starterTextView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func presentAccessory() {
        guard isViewLoaded,
              view.window != nil
        else {
            return
        }

        starterTextView.keyboardAccessoryView = accessoryContainer
        accessoryContainer.isPresentationActive = true
        if !starterTextView.isFirstResponder {
            starterTextView.reloadInputViews()
            starterTextView.becomeFirstResponder()
        }
    }

    private func reloadActiveInputViews() {
        if starterTextView.isFirstResponder {
            starterTextView.reloadInputViews()
        }
    }

    private func observeKeyboardDismissal() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        guard isPresentationRequested ||
              starterTextView.isFirstResponder
        else {
            return
        }

        isPresentationRequested = false
        accessoryContainer.isPresentationActive = false
        onPresentationChange?(false)
    }

    @objc private func handleKeyboardDidHide(_ notification: Notification) {
        guard !isPresentationRequested,
              accessoryContainer.isPresentationActive ||
                starterTextView.keyboardAccessoryView === accessoryContainer
        else {
            return
        }

        cleanupDismissedAccessory()
    }

    private func cleanupDismissedAccessory() {
        accessoryContainer.isPresentationActive = false
        starterTextView.keyboardAccessoryView = nil
        starterTextView.reloadInputViews()
    }

    public func textViewDidChange(_ textView: UITextView) {
        guard textView === starterTextView else {
            return
        }

        accessoryContainer.applyInputText(textView.text)
        onTextChange?(textView.text)
    }
}
