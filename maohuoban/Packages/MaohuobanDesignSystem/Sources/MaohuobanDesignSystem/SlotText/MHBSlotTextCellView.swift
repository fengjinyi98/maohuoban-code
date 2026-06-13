// MHBSlotTextCellView 单字符滚轮容器
// 核心职责：
// - 用隐藏 sizer 维持字符 cell 的准确尺寸
// - 在裁剪区域内驱动旧字符滑出和新字符滑入

import UIKit

// MHBSlotTextCellView 单字符滚轮容器
// 核心职责：
// - 承载一个字符的静态展示和滚动动画
// - 管理字符宽高变化时的 cell 尺寸过渡
@MainActor
final class MHBSlotTextCellView: UIView {
    private let sizerLabel = UILabel()
    private var faceLabels: [UILabel] = []
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var activeAnimators: [UIViewPropertyAnimator] = []

    var character: String
    var font: UIFont {
        didSet {
            sizerLabel.font = font
            faceLabels.forEach { $0.font = font }
            applySize(for: character)
        }
    }
    var textColor: UIColor {
        didSet {
            faceLabels.forEach { $0.textColor = textColor }
        }
    }

    init(character: String, font: UIFont, textColor: UIColor) {
        self.character = character
        self.font = font
        self.textColor = textColor
        super.init(frame: .zero)

        clipsToBounds = true
        isAccessibilityElement = false
        setupSizerLabel()
        setCharacterImmediately(character)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let localBounds = CGRect(origin: .zero, size: bounds.size)
        faceLabels.forEach {
            $0.bounds = localBounds
            $0.center = center
        }
    }

    func setCharacterImmediately(_ character: String) {
        cancelAnimation()
        self.character = character
        faceLabels.forEach { $0.removeFromSuperview() }
        faceLabels = [makeFace(character: character, color: textColor)]
        faceLabels.forEach { addSubview($0) }
        applySize(for: character)
        setNeedsLayout()
        layoutIfNeeded()
    }

    func animate(
        transition: MHBSlotTextCharacterTransition,
        configuration: MHBSlotTextConfiguration,
        restColor: UIColor,
        completion: @escaping () -> Void
    ) {
        cancelAnimation()

        let oldFace = faceLabels.last
        let incomingColor = configuration.colorStyle.color(
            index: transition.index,
            total: transition.totalCharacterCount
        ) ?? restColor
        let newFace = makeFace(character: transition.toCharacter, color: incomingColor)
        newFace.transform = CGAffineTransform(
            translationX: 0,
            y: transition.incomingStartOffsetY
        ).rotated(by: transition.tiltDegrees * .pi / 180)
        addSubview(newFace)
        faceLabels.append(newFace)

        let targetWidth = measuredSize(for: transition.toCharacter).width
        let targetHeight = measuredHeight

        let sizeAnimator = UIViewPropertyAnimator(
            duration: transition.duration,
            curve: .easeOut
        ) { [weak self] in
            self?.widthConstraint?.constant = targetWidth
            self?.heightConstraint?.constant = targetHeight
            self?.superview?.layoutIfNeeded()
        }
        activeAnimators.append(sizeAnimator)
        sizeAnimator.startAnimation(afterDelay: transition.delay)

        if let oldFace {
            let exitAnimator = makeRollAnimator(duration: transition.duration) {
                oldFace.transform = CGAffineTransform(
                    translationX: 0,
                    y: transition.outgoingOffsetY
                ).rotated(by: -transition.tiltDegrees * .pi / 180)
            }
            activeAnimators.append(exitAnimator)
            exitAnimator.startAnimation(afterDelay: transition.delay)
        }

        let enterAnimator = makeRollAnimator(duration: transition.duration) {
            newFace.transform = .identity
        }
        enterAnimator.addCompletion { [weak self, weak newFace] _ in
            guard let self, let newFace else {
                return
            }

            self.character = transition.toCharacter
            self.faceLabels
                .filter { $0 !== newFace }
                .forEach { $0.removeFromSuperview() }
            self.faceLabels = [newFace]
            self.applySize(for: transition.toCharacter)
            self.activeAnimators.removeAll()
            completion()
        }
        activeAnimators.append(enterAnimator)
        enterAnimator.startAnimation(afterDelay: transition.delay + configuration.exitOffset)

        if configuration.colorStyle != .none {
            UIView.animate(
                withDuration: transition.colorFade,
                delay: transition.delay + configuration.exitOffset + transition.duration,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                newFace.textColor = restColor
            }
        }
    }

    func cancelAnimation() {
        activeAnimators.forEach {
            $0.stopAnimation(true)
        }
        activeAnimators.removeAll()
        layer.removeAllAnimations()
        faceLabels.forEach { $0.layer.removeAllAnimations() }
    }

    private func setupSizerLabel() {
        sizerLabel.font = font
        sizerLabel.alpha = 0
        sizerLabel.isAccessibilityElement = false
        addSubview(sizerLabel)
    }

    private func makeFace(character: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = font
        label.textColor = color
        label.textAlignment = .center
        label.text = Self.glyph(character)
        label.isAccessibilityElement = false
        return label
    }

    private func makeRollAnimator(
        duration: TimeInterval,
        animations: @escaping () -> Void
    ) -> UIViewPropertyAnimator {
        let timing = UICubicTimingParameters(
            controlPoint1: CGPoint(x: 0.34, y: 1.56),
            controlPoint2: CGPoint(x: 0.64, y: 1)
        )
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
        animator.addAnimations(animations)
        return animator
    }

    private func applySize(for character: String) {
        let size = measuredSize(for: character)
        sizerLabel.text = Self.glyph(character)
        sizerLabel.frame = CGRect(origin: .zero, size: size)
        applyConstraint(&widthConstraint, attribute: widthAnchor, constant: size.width)
        applyConstraint(&heightConstraint, attribute: heightAnchor, constant: measuredHeight)
        invalidateIntrinsicContentSize()
    }

    private func measuredSize(for character: String) -> CGSize {
        let measuringLabel = UILabel()
        measuringLabel.font = font
        measuringLabel.text = Self.glyph(character)
        let size = measuringLabel.intrinsicContentSize

        return CGSize(
            width: max(ceil(size.width), character.isEmpty ? 0 : 1),
            height: measuredHeight
        )
    }

    private var measuredHeight: CGFloat {
        ceil(font.lineHeight * 1.3)
    }

    private func applyConstraint(
        _ constraint: inout NSLayoutConstraint?,
        attribute: NSLayoutDimension,
        constant: CGFloat
    ) {
        if let constraint {
            constraint.constant = constant
        } else {
            let newConstraint = attribute.constraint(equalToConstant: constant)
            newConstraint.isActive = true
            constraint = newConstraint
        }
    }

    private static func glyph(_ character: String) -> String {
        character == " " ? "\u{00A0}" : character
    }
}
