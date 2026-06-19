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

// MHBKeyboardAccessoryTextInputContainerView 键盘附属输入容器
// 核心职责：
// - 承载头部、真实文本输入区和工具栏
// - 通过 intrinsicContentSize 将动态高度回传给键盘系统
@MainActor
private final class MHBKeyboardAccessoryTextInputContainerView: UIView, UITextViewDelegate {
    var onTextChange: ((String) -> Void)?
    var onHeightChange: (() -> Void)?
    var isPresentationActive = false {
        didSet {
            isHidden = !isPresentationActive
            alpha = isPresentationActive ? 1 : 0
            isUserInteractionEnabled = isPresentationActive
            updateCaretState()
        }
    }

    private let fusionView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let stackView = UIStackView()
    private let textContainer = UIView()
    private let textView = MHBKeyboardAccessoryVisibleTextView()
    private let placeholderLabel = UILabel()
    private let caretView = UIView()
    private var headerContentView: (UIView & UIContentView)?
    private var toolbarContentView: (UIView & UIContentView)?
    private var textHeightConstraint: NSLayoutConstraint?
    private var measuredHeight: CGFloat = 1
    private var minTextHeight: CGFloat = 44
    private var maxTextHeight: CGFloat = 120
    private var isApplyingText = false

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight)
    }

    var isTextInputFirstResponder: Bool {
        textView.isFirstResponder
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.fallbackMeasurementWidth, height: 1))
        backgroundColor = .clear
        clipsToBounds = false
        layer.masksToBounds = false
        isHidden = true
        alpha = 0
        isUserInteractionEnabled = false
        configureBackgroundView()
        configureStackView()
        configureTextInput()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTextHeightIfNeeded()
        updateMeasuredHeightIfNeeded()
        updateCaretFrame()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateCaretFrame()
        updateCaretState()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width > 0 ? size.width : measurementWidth, height: measuredHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        CGSize(width: targetSize.width > 0 ? targetSize.width : measurementWidth, height: measuredHeight)
    }

    func update<Header: View, Toolbar: View>(
        text: String,
        placeholder: String,
        minTextHeight: CGFloat,
        maxTextHeight: CGFloat,
        font: UIFont,
        textColor: UIColor,
        placeholderColor: UIColor,
        tintColor: UIColor,
        header: Header,
        toolbar: Toolbar
    ) {
        self.minTextHeight = minTextHeight
        self.maxTextHeight = max(minTextHeight, maxTextHeight)
        updateHostedContent(header: header, toolbar: toolbar)
        textView.font = font
        textView.textColor = textColor
        textView.tintColor = tintColor
        caretView.backgroundColor = tintColor
        placeholderLabel.text = placeholder
        placeholderLabel.font = font
        placeholderLabel.textColor = placeholderColor
        if textView.text != text {
            isApplyingText = true
            textView.text = text
            isApplyingText = false
        }
        placeholderLabel.isHidden = !text.isEmpty
        updateTextHeightIfNeeded()
        updateMeasuredHeightIfNeeded()
        updateCaretFrame()
        updateCaretState()
    }

    func becomeInputFirstResponder() -> Bool {
        guard window != nil,
              !textView.isFirstResponder
        else {
            return textView.isFirstResponder
        }

        return textView.becomeFirstResponder()
    }

    func resignInput() {
        textView.resignFirstResponder()
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isApplyingText else {
            return
        }

        placeholderLabel.isHidden = !textView.text.isEmpty
        updateTextHeightIfNeeded()
        updateMeasuredHeightIfNeeded()
        onTextChange?(textView.text)
    }

    private func configureBackgroundView() {
        fusionView.isUserInteractionEnabled = false
        fusionView.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.22)
        fusionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fusionView)

        backgroundView.layer.cornerRadius = 28
        backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backgroundView.layer.masksToBounds = true
        backgroundView.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.28)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        NSLayoutConstraint.activate([
            fusionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fusionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fusionView.topAnchor.constraint(equalTo: bottomAnchor, constant: -Self.fusionInsideOverlap),
            fusionView.heightAnchor.constraint(equalToConstant: Self.fusionInsideOverlap + Self.keyboardFusionOverlap),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configureStackView() {
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalInset),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalInset),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: Self.topInset),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.bottomInset)
        ])
    }

    private func configureTextInput() {
        textContainer.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.24)
        textContainer.layer.cornerRadius = 14
        textContainer.clipsToBounds = true
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.spellCheckingType = .yes
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        caretView.backgroundColor = textView.tintColor
        caretView.layer.cornerRadius = 1
        caretView.isUserInteractionEnabled = false
        textContainer.addSubview(textView)
        textContainer.addSubview(placeholderLabel)
        textContainer.addSubview(caretView)
        let textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: minTextHeight)
        self.textHeightConstraint = textHeightConstraint
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            textView.topAnchor.constraint(equalTo: textContainer.topAnchor),
            textView.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor),
            textHeightConstraint,
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -16),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 10)
        ])
    }

    func applyInputText(_ text: String) {
        guard textView.text != text else {
            return
        }

        isApplyingText = true
        textView.text = text
        isApplyingText = false
        placeholderLabel.isHidden = !text.isEmpty
        updateTextHeightIfNeeded()
        updateMeasuredHeightIfNeeded()
        updateCaretFrame()
    }

    private func updateCaretFrame() {
        guard textContainer.bounds.width > 0,
              textView.bounds.width > 0
        else {
            return
        }

        textView.layoutIfNeeded()
        let caretRect = textView.caretRect(for: textView.endOfDocument)
        let convertedCaretRect = textView.convert(caretRect, to: textContainer)
        let fontLineHeight = textView.font?.lineHeight ?? 18
        let caretHeight = ceil(max(18, min(fontLineHeight, textView.bounds.height - textView.textContainerInset.top - textView.textContainerInset.bottom)))
        let fallbackX = textView.frame.minX + textView.textContainerInset.left
        let fallbackY = textView.frame.minY + textView.textContainerInset.top
        let proposedX = convertedCaretRect.minX.isFinite ? convertedCaretRect.minX : fallbackX
        let proposedY = convertedCaretRect.minY.isFinite ? convertedCaretRect.minY : fallbackY
        let maxX = max(fallbackX, textContainer.bounds.width - textView.textContainerInset.right - Self.caretWidth)
        let maxY = max(fallbackY, textContainer.bounds.height - textView.textContainerInset.bottom - caretHeight)
        caretView.frame = CGRect(
            x: min(max(proposedX, fallbackX), maxX),
            y: min(max(proposedY, fallbackY), maxY),
            width: Self.caretWidth,
            height: caretHeight
        )
    }

    private func updateCaretState() {
        let shouldShowCaret = isPresentationActive && window != nil
        caretView.isHidden = !shouldShowCaret
        if shouldShowCaret {
            startCaretBlinkingIfNeeded()
        } else {
            caretView.layer.removeAnimation(forKey: Self.caretBlinkAnimationKey)
        }
    }

    private func startCaretBlinkingIfNeeded() {
        guard caretView.layer.animation(forKey: Self.caretBlinkAnimationKey) == nil else {
            return
        }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.duration = 0.7
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        caretView.layer.add(animation, forKey: Self.caretBlinkAnimationKey)
    }

    private func updateHostedContent<Header: View, Toolbar: View>(
        header: Header,
        toolbar: Toolbar
    ) {
        updateContentView(&headerContentView, with: header, at: 0)
        installTextContainerIfNeeded()
        let toolbarIndex = stackView.arrangedSubviews.count
        updateContentView(&toolbarContentView, with: toolbar, at: toolbarIndex)
    }

    private func updateContentView<Content: View>(
        _ contentView: inout (UIView & UIContentView)?,
        with content: Content,
        at index: Int
    ) {
        let configuration = UIHostingConfiguration {
            content
        }
        .margins(.all, 0)

        if let contentView {
            contentView.configuration = configuration
        } else {
            let view = configuration.makeContentView()
            view.backgroundColor = .clear
            contentView = view
            stackView.insertArrangedSubview(view, at: min(index, stackView.arrangedSubviews.count))
        }
    }

    private func installTextContainerIfNeeded() {
        guard textContainer.superview == nil else {
            return
        }

        stackView.insertArrangedSubview(textContainer, at: min(1, stackView.arrangedSubviews.count))
    }

    private func updateTextHeightIfNeeded() {
        let fittingWidth = max(1, textView.bounds.width)
        let fittingSize = CGSize(width: fittingWidth, height: CGFloat.greatestFiniteMagnitude)
        let contentHeight = textView.sizeThatFits(fittingSize).height
        let nextHeight = ceil(min(max(contentHeight, minTextHeight), maxTextHeight))
        guard abs((textHeightConstraint?.constant ?? 0) - nextHeight) > 0.5 else {
            return
        }

        textHeightConstraint?.constant = nextHeight
        textView.isScrollEnabled = contentHeight > maxTextHeight
        onHeightChange?()
    }

    private func updateMeasuredHeightIfNeeded() {
        let stackWidth = max(1, measurementWidth - (Self.horizontalInset * 2))
        let fittingSize = CGSize(width: stackWidth, height: UIView.layoutFittingCompressedSize.height)
        let measuredSize = stackView.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let nextHeight = ceil(max(1, measuredSize.height + Self.topInset + Self.bottomInset))
        guard abs(nextHeight - measuredHeight) > 0.5 else {
            return
        }

        measuredHeight = nextHeight
        frame.size.height = nextHeight
        invalidateIntrinsicContentSize()
        onHeightChange?()
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

    private static let horizontalInset: CGFloat = 20
    private static let topInset: CGFloat = 20
    private static let bottomInset: CGFloat = 16
    private static let fusionInsideOverlap: CGFloat = 2
    private static let keyboardFusionOverlap: CGFloat = 24
    private static let caretWidth: CGFloat = 2
    private static let caretBlinkAnimationKey = "MHBKeyboardAccessoryCaretBlink"
}

// MHBKeyboardAccessoryStarterTextView 键盘启动输入源
// 核心职责：
// - 负责首次成为 first responder 拉起系统键盘
// - 将 accessory 容器交给 UIKit 键盘系统
@MainActor
private final class MHBKeyboardAccessoryStarterTextView: UITextView {
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

// MHBKeyboardAccessoryVisibleTextView 键盘附属可见文本输入源
// 核心职责：
// - 在 accessory 内承载真实输入、光标和选区
// - 保持自身不再返回父级 accessory，避免系统键盘重复计算附属高度
@MainActor
private final class MHBKeyboardAccessoryVisibleTextView: UITextView, MHBKeyboardVisibleTextInput {
    override var inputAccessoryView: UIView? {
        get {
            nil
        }
        set {
            // 可见输入框位于父级 accessory 内部，忽略 UIKit 对同一 accessory 的回写。
        }
    }
}
