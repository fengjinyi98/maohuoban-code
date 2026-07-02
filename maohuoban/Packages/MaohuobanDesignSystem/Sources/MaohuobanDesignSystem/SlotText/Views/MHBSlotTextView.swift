// MHBSlotTextView UIKit 滚轮文字视图
// 核心职责：
// - 按字符拆分文本并驱动滚轮式切换动画
// - 提供永久 set 与临时 flash 两种复用入口

import UIKit

// MHBSlotTextView UIKit 滚轮文字视图
// 核心职责：
// - 管理字符 cell 的创建、复用和收尾重建
// - 处理动画中断、延迟队列与 flash 自动回退
@MainActor
public final class MHBSlotTextView: UIView {
    private let stackView = UIStackView()
    private var cells: [MHBSlotTextCellView] = []
    private var pendingRequest: SlotTextRequest?
    private var revertTimer: Timer?
    private var flashBaseText: String?
    private var remainingAnimations = 0
    private var animationTarget: String?

    public private(set) var currentText: String
    public var configuration: MHBSlotTextConfiguration

    public var font: UIFont {
        didSet {
            cells.forEach { $0.font = font }
            invalidateIntrinsicContentSize()
        }
    }

    public var textColor: UIColor {
        didSet {
            cells.forEach { $0.textColor = textColor }
        }
    }

    var slotCellCount: Int {
        cells.count
    }

    var pendingFlashBaseText: String? {
        flashBaseText
    }

    public init(
        text: String = "",
        configuration: MHBSlotTextConfiguration = .default,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label
    ) {
        self.currentText = text
        self.configuration = configuration
        self.font = font
        self.textColor = textColor
        super.init(frame: .zero)

        setupStackView()
        rebuild(text)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var intrinsicContentSize: CGSize {
        stackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    }

    public func setText(
        _ text: String,
        animated: Bool = true,
        configuration: MHBSlotTextConfiguration? = nil
    ) {
        revertTimer?.invalidate()
        revertTimer = nil
        flashBaseText = nil
        applyText(text, animated: animated, configuration: configuration ?? self.configuration)
    }

    public func flash(
        _ text: String,
        revertAfter: TimeInterval = 1.4,
        enter: MHBSlotTextConfiguration = .default,
        exit: MHBSlotTextConfiguration = .default.with(direction: .up)
    ) {
        if flashBaseText == nil {
            flashBaseText = currentText
        }

        let previousText = flashBaseText ?? currentText
        revertTimer?.invalidate()
        applyText(text, animated: true, configuration: enter)

        revertTimer = Timer.scheduledTimer(withTimeInterval: revertAfter, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flashBaseText = nil
                self?.applyText(previousText, animated: true, configuration: exit)
            }
        }
    }

    public func destroy(replacementText: String = "") {
        revertTimer?.invalidate()
        revertTimer = nil
        flashBaseText = nil
        cancelInFlightAnimation()
        rebuild(replacementText)
    }

    private func setupStackView() {
        isAccessibilityElement = true
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }

    private func applyText(
        _ text: String,
        animated: Bool,
        configuration: MHBSlotTextConfiguration
    ) {
        guard text != currentText || animationTarget != nil else {
            return
        }

        if !animated || cells.isEmpty {
            cancelInFlightAnimation()
            rebuild(text)
            return
        }

        if animationTarget != nil && !configuration.interrupt {
            pendingRequest = SlotTextRequest(text: text, configuration: configuration)
            return
        }

        cancelInFlightAnimation()

        let plan = MHBSlotTextTransitionPlan(
            from: currentText,
            to: text,
            lineHeight: ceil(font.lineHeight * 1.3),
            configuration: configuration
        )

        guard !plan.transitions.isEmpty else {
            rebuild(text)
            return
        }

        animationTarget = text
        accessibilityLabel = text
        prepareCells(maxLength: max(currentText.slotTextCharacters.count, text.slotTextCharacters.count))
        remainingAnimations = plan.transitions.count

        for transition in plan.transitions {
            cells[transition.index].animate(
                transition: transition,
                configuration: configuration,
                restColor: textColor
            ) { [weak self] in
                self?.finishCharacterAnimation(target: text)
            }
        }
    }

    private func finishCharacterAnimation(target: String) {
        remainingAnimations -= 1

        guard remainingAnimations <= 0 else {
            return
        }

        rebuild(target)
        animationTarget = nil

        if let pendingRequest {
            self.pendingRequest = nil
            applyText(
                pendingRequest.text,
                animated: true,
                configuration: pendingRequest.configuration
            )
        }
    }

    private func prepareCells(maxLength: Int) {
        while cells.count < maxLength {
            let cell = MHBSlotTextCellView(character: "", font: font, textColor: textColor)
            cells.append(cell)
            stackView.addArrangedSubview(cell)
        }
    }

    private func rebuild(_ text: String) {
        cells.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        cells = text.slotTextCharacters.map {
            MHBSlotTextCellView(character: $0, font: font, textColor: textColor)
        }
        cells.forEach { stackView.addArrangedSubview($0) }
        currentText = text
        animationTarget = nil
        remainingAnimations = 0
        accessibilityLabel = text
        invalidateIntrinsicContentSize()
    }

    private func cancelInFlightAnimation() {
        cells.forEach { $0.cancelAnimation() }

        if let animationTarget {
            rebuild(animationTarget)
        }

        animationTarget = nil
        remainingAnimations = 0
    }
}

private struct SlotTextRequest {
    let text: String
    let configuration: MHBSlotTextConfiguration
}

private extension String {
    var slotTextCharacters: [String] {
        Array(self).map(String.init)
    }
}
