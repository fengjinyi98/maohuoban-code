import UIKit

// MHBKeyboardAccessoryInputTextView 键盘输入源
// 核心职责：
// - 作为真实 first responder 拉起系统软键盘
// - 把 DesignSystem 管理的 accessory 容器稳定挂到 UIKit 输入链
@MainActor
final class MHBKeyboardAccessoryInputTextView: UITextView {
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
final class MHBKeyboardAccessoryContainerView: UIView {
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
