import SwiftUI
import UIKit

// MHBKeyboardVisibleTextInput 可见键盘输入源标记
// 核心职责：
// - 标识由 DesignSystem 管理的可见 UITextView 输入源
// - 让隐藏 keyboard accessory host 避免抢占当前输入焦点
@MainActor
public protocol MHBKeyboardVisibleTextInput: UIResponder {}

// MHBKeyboardTextView 可见键盘文本编辑视图
// 核心职责：
// - 使用真实 UITextView 承载多行输入、光标和选区
// - 将 SwiftUI 工具条挂载到当前输入源的 inputAccessoryView
public struct MHBKeyboardTextView<Accessory: View>: UIViewRepresentable {
    @Binding private var text: String
    private let isFirstResponder: Bool
    private let placeholder: String
    private let font: UIFont
    private let textColor: UIColor
    private let placeholderColor: UIColor
    private let tintColor: UIColor
    private let accessory: () -> Accessory

    public init(
        text: Binding<String>,
        isFirstResponder: Bool,
        placeholder: String,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        placeholderColor: UIColor = .placeholderText,
        tintColor: UIColor = .systemBlue,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        _text = text
        self.isFirstResponder = isFirstResponder
        self.placeholder = placeholder
        self.font = font
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.tintColor = tintColor
        self.accessory = accessory
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    public func makeUIView(context: Context) -> MHBKeyboardTextUIKitView<Accessory> {
        let textView = MHBKeyboardTextUIKitView<Accessory>()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.spellCheckingType = .yes
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        return textView
    }

    public func updateUIView(_ uiView: MHBKeyboardTextUIKitView<Accessory>, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isApplyingSwiftUIText = true
        uiView.apply(
            text: text,
            placeholder: placeholder,
            font: font,
            textColor: textColor,
            placeholderColor: placeholderColor,
            tintColor: tintColor,
            accessory: accessory()
        )
        context.coordinator.isApplyingSwiftUIText = false

        uiView.mhbSetFirstResponderRequested(isFirstResponder)
    }

    // Coordinator UITextView 文本同步协调器
    // 核心职责：
    // - 将 UIKit 输入变化同步回 SwiftUI Binding
    // - 避免 SwiftUI 回写文本时形成重复通知
    @MainActor
    public final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isApplyingSwiftUIText = false

        init(text: Binding<String>) {
            self.text = text
        }

        public func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingSwiftUIText,
                  text.wrappedValue != textView.text
            else {
                return
            }

            text.wrappedValue = textView.text
        }
    }
}

// MHBKeyboardTextUIKitView UIKit 可见文本输入源
// 核心职责：
// - 提供 inputAccessoryView 给系统键盘
// - 管理占位文本和 SwiftUI 工具条宿主视图
@MainActor
public final class MHBKeyboardTextUIKitView<Accessory: View>: UITextView, MHBKeyboardVisibleTextInput {
    private let accessoryContainer = MHBKeyboardTextAccessoryContainerView()
    private var customInputAccessoryView: UIView?
    private var accessoryContentView: (UIView & UIContentView)?
    private var isShowingPlaceholder = false
    private var isFirstResponderRequested = false

    public override var inputAccessoryView: UIView? {
        get {
            customInputAccessoryView ?? accessoryContainer
        }
        set {
            customInputAccessoryView = newValue
        }
    }

    func apply(
        text: String,
        placeholder: String,
        font: UIFont,
        textColor: UIColor,
        placeholderColor: UIColor,
        tintColor: UIColor,
        accessory: Accessory
    ) {
        self.font = font
        self.tintColor = tintColor
        updateAccessory(accessory)

        if text.isEmpty, !isFirstResponder {
            showPlaceholder(placeholder, color: placeholderColor)
        } else {
            showText(text, color: textColor)
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        syncFirstResponderRequest(reason: "didMoveToWindow")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        syncFirstResponderRequest(reason: "layoutSubviews")
    }

    func mhbSetFirstResponderRequested(_ isRequested: Bool) {
        isFirstResponderRequested = isRequested
        syncFirstResponderRequest(reason: "stateUpdate")
    }

    private func syncFirstResponderRequest(reason: String) {
        if isFirstResponderRequested {
            mhbBecomeFirstResponderIfNeeded(reason: reason)
        } else {
            mhbResignFirstResponderIfNeeded(reason: reason)
        }
    }

    private func mhbBecomeFirstResponderIfNeeded(reason: String) {
        guard !isFirstResponder else {
            return
        }

        guard window != nil,
              bounds.width > 0,
              bounds.height > 0
        else {
            return
        }

        becomeFirstResponder()
        if isShowingPlaceholder {
            text = ""
            textColor = .label
            isShowingPlaceholder = false
        }
    }

    private func mhbResignFirstResponderIfNeeded(reason: String) {
        guard isFirstResponder else {
            return
        }

        resignFirstResponder()
    }

    private func showPlaceholder(_ placeholder: String, color: UIColor) {
        guard text != placeholder || !isShowingPlaceholder else {
            return
        }

        text = placeholder
        textColor = color
        isShowingPlaceholder = true
    }

    private func showText(_ text: String, color: UIColor) {
        if self.text != text || isShowingPlaceholder {
            self.text = text
        }
        textColor = color
        isShowingPlaceholder = false
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
        reloadInputViews()
    }
}

// MHBKeyboardTextAccessoryContainerView 键盘工具条容器
// 核心职责：
// - 承载 SwiftUI 工具条内容
// - 通过 intrinsicContentSize 向键盘系统提供稳定高度
@MainActor
private final class MHBKeyboardTextAccessoryContainerView: UIView {
    private weak var hostedView: UIView?
    private var measuredHeight: CGFloat = 0
    private var heightConstraint: NSLayoutConstraint?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight)
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.fallbackMeasurementWidth, height: 0))
        backgroundColor = .clear
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

    func invalidateHostedContentSize() {
        updateMeasuredHeightIfNeeded()
        invalidateIntrinsicContentSize()
    }

    private func updateMeasuredHeightIfNeeded() {
        guard let hostedView else {
            return
        }

        hostedView.setNeedsLayout()
        let measuredSize = hostedView.systemLayoutSizeFitting(
            CGSize(width: measurementWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let nextHeight = ceil(max(0, measuredSize.height))
        guard abs(nextHeight - measuredHeight) > 0.5 else {
            return
        }

        measuredHeight = nextHeight
        heightConstraint?.constant = nextHeight
        frame.size.height = nextHeight
        invalidateIntrinsicContentSize()
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
