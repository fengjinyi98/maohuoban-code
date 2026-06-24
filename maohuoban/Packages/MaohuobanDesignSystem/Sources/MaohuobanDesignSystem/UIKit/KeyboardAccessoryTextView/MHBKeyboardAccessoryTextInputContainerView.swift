import SwiftUI
import UIKit

// MHBKeyboardAccessoryTextInputContainerView 键盘附属输入容器
// 核心职责：
// - 承载头部、真实文本输入区和工具栏
// - 通过 intrinsicContentSize 将动态高度回传给键盘系统
@MainActor
final class MHBKeyboardAccessoryTextInputContainerView: UIView, UITextViewDelegate {
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

    private let fusionView: UIView & UIContentView = MHBKeyboardAccessoryTextInputContainerView.makeFusionGlassView()
    private let backgroundView: UIView & UIContentView = MHBKeyboardAccessoryTextInputContainerView.makePanelGlassView()
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

    private func configureBackgroundView() {
        fusionView.isUserInteractionEnabled = false
        fusionView.backgroundColor = .clear
        fusionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fusionView)

        backgroundView.backgroundColor = .clear
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
        textContainer.backgroundColor = MHBTheme.ColorToken.separator.uiColor
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
