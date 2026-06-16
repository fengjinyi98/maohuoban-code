import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MHBVariableBlurDirection 可变模糊方向
// 核心职责：
// - 描述渐进模糊遮罩的强弱方向
// - 为沉浸式头图和顶部材质提供统一参数
enum MHBVariableBlurDirection: String, Equatable {
    case blurredTopClearBottom
    case blurredBottomClearTop
    case blurredAll
}

// MHBVariableBlurView UIKit 可变模糊 SwiftUI 包装
// 核心职责：
// - 使用系统 backdrop layer 对下方内容施加渐进式模糊
// - 为需要渐进背景模糊的 SwiftUI 场景提供可复用基础视图
struct MHBVariableBlurView: UIViewRepresentable {
    let maxBlurRadius: CGFloat
    let direction: MHBVariableBlurDirection
    let startOffset: CGFloat

    init(
        maxBlurRadius: CGFloat = 20,
        direction: MHBVariableBlurDirection = .blurredTopClearBottom,
        startOffset: CGFloat = 0
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
    }

    func makeUIView(context: Context) -> MHBVariableBlurUIView {
        MHBVariableBlurUIView(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
    }

    func updateUIView(_ uiView: MHBVariableBlurUIView, context: Context) {
        uiView.updateConfiguration(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
    }
}

// MHBVariableBlurUIView 可变模糊 UIKit 视图
// 核心职责：
// - 配置 backdrop layer 的可变模糊滤镜
// - 隐藏标准 UIVisualEffectView 附带的 tint 层，避免硬边界
final class MHBVariableBlurUIView: UIVisualEffectView {
    private var currentMaxBlurRadius: CGFloat
    private var currentDirection: MHBVariableBlurDirection
    private var currentStartOffset: CGFloat
    private var lastConfiguredBounds: CGRect = .null

    init(
        maxBlurRadius: CGFloat = 20,
        direction: MHBVariableBlurDirection = .blurredTopClearBottom,
        startOffset: CGFloat = 0
    ) {
        self.currentMaxBlurRadius = maxBlurRadius
        self.currentDirection = direction
        self.currentStartOffset = startOffset

        super.init(effect: UIBlurEffect(style: .regular))

        configureVariableBlur(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reconfigureForCurrentStateIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard let window, let backdropLayer = subviews.first?.layer else {
            return
        }

        backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
        reconfigureForCurrentStateIfNeeded()
    }

    func updateConfiguration(
        maxBlurRadius: CGFloat,
        direction: MHBVariableBlurDirection,
        startOffset: CGFloat
    ) {
        let changed = currentMaxBlurRadius != maxBlurRadius
            || currentDirection != direction
            || currentStartOffset != startOffset

        guard changed else {
            return
        }

        currentMaxBlurRadius = maxBlurRadius
        currentDirection = direction
        currentStartOffset = startOffset

        configureVariableBlur(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
    }

    private func reconfigureForCurrentStateIfNeeded() {
        guard window != nil else {
            return
        }

        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let filtersCount = subviews.first?.layer.filters?.count ?? 0
        let needsReconfigure = bounds != lastConfiguredBounds || filtersCount != 1

        guard needsReconfigure else {
            return
        }

        lastConfiguredBounds = bounds
        configureVariableBlur(
            maxBlurRadius: currentMaxBlurRadius,
            direction: currentDirection,
            startOffset: currentStartOffset
        )
    }

    private func configureVariableBlur(
        maxBlurRadius: CGFloat,
        direction: MHBVariableBlurDirection,
        startOffset: CGFloat
    ) {
        let filterClassName = String("retliFAC".reversed())

        guard
            let filterClass = NSClassFromString(filterClassName) as? NSObject.Type,
            let filter = filterClass
                .perform(NSSelectorFromString(String(":epyThtiWretlif".reversed())), with: "variableBlur")?
                .takeUnretainedValue() as? NSObject
        else {
            clearStandardEffectLayers()
            return
        }

        filter.setValue(maxBlurRadius, forKey: "inputRadius")
        filter.setValue(
            makeGradientMaskImage(startOffset: startOffset, direction: direction),
            forKey: "inputMaskImage"
        )
        filter.setValue(true, forKey: "inputNormalizeEdges")

        let backdropLayer = subviews.first?.layer
        backdropLayer?.filters = [filter]
        clearStandardEffectLayers()
    }

    private func clearStandardEffectLayers() {
        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    private func makeGradientMaskImage(
        width: CGFloat = 100,
        height: CGFloat = 100,
        startOffset: CGFloat,
        direction: MHBVariableBlurDirection
    ) -> CGImage {
        if direction == .blurredAll {
            return makeSolidMaskImage(width: width, height: height)
        }

        let gradientFilter = CIFilter.linearGradient()
        gradientFilter.color0 = CIColor.black
        gradientFilter.color1 = CIColor.clear
        gradientFilter.point0 = CGPoint(x: 0, y: height)
        gradientFilter.point1 = CGPoint(x: 0, y: startOffset * height)

        if direction == .blurredBottomClearTop {
            gradientFilter.point0.y = 0
            gradientFilter.point1.y = height - gradientFilter.point1.y
        }

        let output = CIContext().createCGImage(
            gradientFilter.outputImage ?? CIImage.empty(),
            from: CGRect(x: 0, y: 0, width: width, height: height)
        ) ?? CGImage.emptyMask

        return output
    }

    private func makeSolidMaskImage(width: CGFloat, height: CGFloat) -> CGImage {
        let context = CIContext()
        let image = CIImage(color: .black)
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))

        let output = context.createCGImage(
            image,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        ) ?? CGImage.emptyMask

        return output
    }
}

private extension CGImage {
    static var emptyMask: CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 1,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        return context?.makeImage() ?? CGImage(
            maskWidth: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: 1,
            provider: CGDataProvider(data: Data([0]) as CFData)!,
            decode: nil,
            shouldInterpolate: false
        )!
    }
}
