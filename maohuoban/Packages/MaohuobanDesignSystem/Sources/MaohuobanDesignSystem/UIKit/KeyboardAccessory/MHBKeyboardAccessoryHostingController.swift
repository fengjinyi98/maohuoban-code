import SwiftUI
import UIKit

// MHBKeyboardAccessoryHostingController UIKit 键盘附属视图控制器
// 核心职责：
// - 作为 first responder 提供 inputAccessoryView
// - 管理 SwiftUI accessory 内容的 UIKit 承载视图生命周期
@MainActor
final class MHBKeyboardAccessoryHostingController<Accessory: View>: UIViewController, UITextViewDelegate {
    private let accessoryContainer = MHBKeyboardAccessoryContainerView()
    private let inputTextView = MHBKeyboardAccessoryInputTextView()
    private var accessoryContentView: (UIView & UIContentView)?
    private var isPresentationRequested = false
    private var isAccessoryInstalled = false
    private var onPresentationChange: ((Bool) -> Void)?
    private var onTextChange: ((String) -> Void)?
    private var isApplyingTextFromSwiftUI = false

    override var canBecomeFirstResponder: Bool {
        true
    }

    override var inputAccessoryView: UIView? {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        installInputTextView()
        accessoryContainer.onMeasuredHeightChange = { [weak self] in
            guard let self else {
                return
            }

            self.inputTextView.reloadInputViews()
        }
        observeKeyboardDismissal()
        observeAccessoryContentChanges()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncPresentation()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func update(
        accessory: Accessory,
        isPresented: Bool,
        text: String,
        onPresentationChange: @escaping (Bool) -> Void,
        onTextChange: @escaping (String) -> Void
    ) {
        self.onPresentationChange = onPresentationChange
        self.onTextChange = onTextChange
        isPresentationRequested = isPresented
        applyTextFromSwiftUI(text)
        if isPresented {
            isAccessoryInstalled = true
            inputTextView.keyboardAccessoryView = accessoryContainer
            accessoryContainer.setPresentationActive(true)
        }

        if isPresented {
            updateAccessory(accessory)
            syncPresentation()
        } else {
            clearAccessoryContent(reason: "updateFalse")
        }
    }

    func dismissAccessory() {
        isPresentationRequested = false
        clearAccessoryContent(reason: "dismissAccessory")
        dismissActiveInputResponder(reason: "dismissAccessory")
        inputTextView.reloadInputViews()
    }

    private func installInputTextView() {
        inputTextView.delegate = self
        inputTextView.backgroundColor = .clear
        inputTextView.textColor = .clear
        inputTextView.tintColor = .clear
        inputTextView.font = .preferredFont(forTextStyle: .body)
        inputTextView.autocorrectionType = .yes
        inputTextView.autocapitalizationType = .sentences
        inputTextView.spellCheckingType = .yes
        inputTextView.keyboardDismissMode = .interactive
        inputTextView.isScrollEnabled = false
        inputTextView.textContainerInset = .zero
        inputTextView.textContainer.lineFragmentPadding = 0
        inputTextView.alpha = 0.01
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputTextView)

        NSLayoutConstraint.activate([
            inputTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputTextView.topAnchor.constraint(equalTo: view.topAnchor),
            inputTextView.widthAnchor.constraint(equalToConstant: 1),
            inputTextView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func updateAccessory(_ accessory: Accessory) {
        let configuration = UIHostingConfiguration {
            accessory
        }
        .margins(.all, 0)

        if let accessoryContentView {
            accessoryContentView.configuration = configuration
        } else {
            let contentView = configuration.makeContentView()
            contentView.backgroundColor = .clear
            accessoryContainer.installHostedView(contentView)
            accessoryContentView = contentView
        }

        accessoryContainer.invalidateHostedContentSize()
        inputTextView.reloadInputViews()
    }

    private func clearAccessoryContent(reason: String) {
        isAccessoryInstalled = false
        inputTextView.keyboardAccessoryView = nil
        accessoryContainer.setPresentationActive(false)
        accessoryContentView?.removeFromSuperview()
        accessoryContentView = nil
        accessoryContainer.removeHostedView(reason: reason)
        inputTextView.reloadInputViews()
        dismissManagedInputResponder(reason: reason)
    }

    private func syncPresentation() {
        guard isViewLoaded, view.window != nil else {
            return
        }

        if isPresentationRequested {
            isAccessoryInstalled = true
            inputTextView.keyboardAccessoryView = accessoryContainer
            if !inputTextView.isFirstResponder,
               !isVisibleTextInputFirstResponderActive {
                inputTextView.reloadInputViews()
                inputTextView.becomeFirstResponder()
            }
            accessoryContainer.invalidateHostedContentSize()
            if inputTextView.isFirstResponder {
                inputTextView.reloadInputViews()
            }
        } else {
            clearAccessoryContent(reason: "syncPresentationFalse")
            inputTextView.reloadInputViews()
        }
    }

    private func dismissManagedInputResponder(reason: String) {
        if inputTextView.isFirstResponder {
            inputTextView.resignFirstResponder()
        }

        if isFirstResponder {
            resignFirstResponder()
        }
    }

    private func dismissActiveInputResponder(reason: String) {
        let responderBefore = UIApplication.shared.mhbCurrentFirstResponder
        let responderView = responderBefore as? UIView
        let shouldDismiss = isFirstResponder ||
            inputTextView.isFirstResponder ||
            responderBefore?.inputAccessoryView === accessoryContainer ||
            responderView?.isDescendant(of: accessoryContainer) == true
        guard shouldDismiss else {
            return
        }

        responderBefore?.resignFirstResponder()
        inputTextView.resignFirstResponder()
        resignFirstResponder()

        Task { @MainActor in
            responderBefore?.resignFirstResponder()
            self.inputTextView.resignFirstResponder()
            self.resignFirstResponder()
            self.inputTextView.reloadInputViews()
        }
    }

    private var isVisibleTextInputFirstResponderActive: Bool {
        UIApplication.shared.mhbCurrentFirstResponder is any MHBKeyboardVisibleTextInput
    }

    private func applyTextFromSwiftUI(_ text: String) {
        guard inputTextView.text != text else {
            return
        }

        isApplyingTextFromSwiftUI = true
        inputTextView.text = text
        isApplyingTextFromSwiftUI = false
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isApplyingTextFromSwiftUI else {
            return
        }

        onTextChange?(textView.text)
    }

    private func observeKeyboardDismissal() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardDidShow),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
    }

    private func observeAccessoryContentChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccessoryContentDidChange),
            name: .mhbKeyboardAccessoryContentDidChange,
            object: nil
        )
    }

    @objc private func handleAccessoryContentDidChange() {
        guard isPresentationRequested,
              isAccessoryInstalled
        else {
            return
        }

        accessoryContainer.invalidateHostedContentSize()
        inputTextView.reloadInputViews()
    }

    @objc private func handleKeyboardWillHide() {
        guard isPresentationRequested ||
              inputTextView.isFirstResponder ||
              isFirstResponder
        else {
            return
        }

        let shouldNotifyPresentationChange = isPresentationRequested
        isPresentationRequested = false
        clearAccessoryContent(reason: "keyboardWillHide")
        if shouldNotifyPresentationChange {
            onPresentationChange?(false)
        }
    }

    @objc private func handleKeyboardDidShow() {
        guard !isPresentationRequested else {
            return
        }

        guard inputTextView.isFirstResponder ||
              isFirstResponder ||
              UIApplication.shared.mhbCurrentFirstResponder?.inputAccessoryView === accessoryContainer
        else {
            return
        }

        clearAccessoryContent(reason: "keyboardDidShowWhileDismissed")
        dismissActiveInputResponder(reason: "keyboardDidShowWhileDismissed")
    }
}

@MainActor
private weak var mhbKeyboardAccessoryFirstResponder: UIResponder?

private extension UIApplication {
    var mhbCurrentFirstResponder: UIResponder? {
        mhbKeyboardAccessoryFirstResponder = nil
        sendAction(
            #selector(UIResponder.mhbKeyboardAccessoryCaptureFirstResponder(_:)),
            to: nil,
            from: nil,
            for: nil
        )
        return mhbKeyboardAccessoryFirstResponder
    }
}

private extension UIResponder {
    @objc func mhbKeyboardAccessoryCaptureFirstResponder(_ sender: Any?) {
        mhbKeyboardAccessoryFirstResponder = self
    }
}
