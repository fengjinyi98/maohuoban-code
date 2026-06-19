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

// MHBKeyboardAccessoryHostingController UIKit 键盘附属视图控制器
// 核心职责：
// - 作为 first responder 提供 inputAccessoryView
// - 管理 SwiftUI accessory 内容的 UIKit 承载视图生命周期
@MainActor
private final class MHBKeyboardAccessoryHostingController<Accessory: View>: UIViewController, UITextViewDelegate {
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

// MHBKeyboardAccessoryInputTextView 键盘输入源
// 核心职责：
// - 作为真实 first responder 拉起系统软键盘
// - 把 DesignSystem 管理的 accessory 容器稳定挂到 UIKit 输入链
@MainActor
private final class MHBKeyboardAccessoryInputTextView: UITextView {
    var keyboardAccessoryView: UIView?

    override var inputAccessoryView: UIView? {
        get {
            keyboardAccessoryView
        }
        set {
            keyboardAccessoryView = newValue
        }
    }
}

// MHBKeyboardAccessoryContainerView 自适应键盘附属容器
// 核心职责：
// - 承载 SwiftUI content view
// - 通过显式 fitting size 回传输入工具区高度
@MainActor
private final class MHBKeyboardAccessoryContainerView: UIView {
    var onMeasuredHeightChange: (() -> Void)?

    private weak var hostedView: UIView?
    private var measuredHeight: CGFloat = 1
    private var heightConstraint: NSLayoutConstraint?
    private var isPresentationActive = false

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight)
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.fallbackMeasurementWidth, height: 1))
        backgroundColor = .clear
        clipsToBounds = true
        alpha = 0
        isHidden = true
        isUserInteractionEnabled = false

        let heightConstraint = heightAnchor.constraint(equalToConstant: measuredHeight)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
        self.heightConstraint = heightConstraint
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateMeasuredHeightIfNeeded()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width > 0 ? size.width : measurementWidth
        return CGSize(width: width, height: measuredHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let width = targetSize.width > 0 ? targetSize.width : measurementWidth
        return CGSize(width: width, height: measuredHeight)
    }

    func installHostedView(_ hostedView: UIView) {
        self.hostedView = hostedView
        hostedView.isHidden = !isPresentationActive
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateMeasuredHeightIfNeeded()
    }

    func removeHostedView(reason: String) {
        hostedView?.removeFromSuperview()
        hostedView = nil
        collapseForInactivePresentation()
    }

    func setPresentationActive(_ isActive: Bool) {
        guard isPresentationActive != isActive else {
            if !isActive {
                collapseForInactivePresentation()
            }
            return
        }

        isPresentationActive = isActive
        isHidden = !isActive
        isUserInteractionEnabled = isActive
        alpha = isActive ? 1 : 0
        hostedView?.isHidden = !isActive
        if isActive {
            updateMeasuredHeightIfNeeded()
        } else {
            collapseForInactivePresentation()
        }
    }

    func invalidateHostedContentSize() {
        guard isPresentationActive else {
            collapseForInactivePresentation()
            invalidateIntrinsicContentSize()
            return
        }

        updateMeasuredHeightIfNeeded()
        invalidateIntrinsicContentSize()
    }

    private func updateMeasuredHeightIfNeeded() {
        guard isPresentationActive else {
            collapseForInactivePresentation()
            return
        }

        guard let hostedView else {
            return
        }

        hostedView.setNeedsLayout()
        let fittingSize = CGSize(
            width: measurementWidth,
            height: UIView.layoutFittingCompressedSize.height
        )
        let measuredSize = hostedView.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let nextHeight = ceil(max(1, measuredSize.height))
        guard abs(nextHeight - measuredHeight) > 0.5 else {
            return
        }

        measuredHeight = nextHeight
        heightConstraint?.constant = nextHeight
        frame.size.height = nextHeight
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        onMeasuredHeightChange?()
    }

    private func collapseForInactivePresentation() {
        guard measuredHeight != 1 || heightConstraint?.constant != 1 || frame.height != 1 else {
            return
        }

        measuredHeight = 1
        heightConstraint?.constant = 1
        frame.size.height = 1
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private var measurementWidth: CGFloat {
        [bounds.width, superview?.bounds.width, window?.bounds.width, Self.fallbackMeasurementWidth]
            .compactMap { $0 }
            .first { $0 > 0 }
            ?? Self.fallbackMeasurementWidth
    }

    private static var fallbackMeasurementWidth: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.bounds.width > 0 }?
            .bounds.width
            ?? 393
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

public extension Notification.Name {
    static let mhbKeyboardAccessoryContentDidChange = Notification.Name(
        "MHBKeyboardAccessoryContentDidChange"
    )
}
