import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MHBVariableBlurDirection 可变模糊方向
// 核心职责：
// - 描述渐进模糊遮罩的强弱方向
// - 为沉浸式头图和顶部材质实验提供统一参数
enum MHBVariableBlurDirection: String, Equatable {
    case blurredTopClearBottom
    case blurredBottomClearTop
    case blurredAll
}

// MHBVariableBlurView UIKit 可变模糊 SwiftUI 包装
// 核心职责：
// - 使用系统 backdrop layer 对下方内容施加渐进式模糊
// - 为头图氛围感实验提供可复用的基础视图
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
        MHBVariableBlurDebug.log(
            "makeUIView radius=\(MHBVariableBlurDebug.format(maxBlurRadius)), direction=\(direction.rawValue), startOffset=\(MHBVariableBlurDebug.format(startOffset))"
        )

        return MHBVariableBlurUIView(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
    }

    func updateUIView(_ uiView: MHBVariableBlurUIView, context: Context) {
        MHBVariableBlurDebug.log(
            "updateUIView radius=\(MHBVariableBlurDebug.format(maxBlurRadius)), direction=\(direction.rawValue), startOffset=\(MHBVariableBlurDebug.format(startOffset)), bounds=\(MHBVariableBlurDebug.format(uiView.bounds))"
        )

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
    private var lastLoggedBounds: CGRect = .null
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

        MHBVariableBlurDebug.log(
            "init effect=\(String(describing: effect)), radius=\(MHBVariableBlurDebug.format(maxBlurRadius)), direction=\(direction.rawValue), startOffset=\(MHBVariableBlurDebug.format(startOffset))"
        )

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

        guard bounds != lastLoggedBounds else {
            return
        }

        lastLoggedBounds = bounds
        MHBVariableBlurDebug.log(
            "layoutSubviews bounds=\(MHBVariableBlurDebug.format(bounds)), subviews=\(subviews.count), firstSubviewFrame=\(subviews.first.map { MHBVariableBlurDebug.format($0.frame) } ?? "nil")"
        )

        reconfigureForCurrentStateIfNeeded(reason: "layoutSubviews")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        MHBVariableBlurDebug.log(
            "didMoveToWindow windowExists=\(window != nil), bounds=\(MHBVariableBlurDebug.format(bounds)), subviews=\(subviews.count)"
        )

        guard let window, let backdropLayer = subviews.first?.layer else {
            MHBVariableBlurDebug.log("didMoveToWindow skipped backdropLayerExists=\(subviews.first?.layer != nil)")
            return
        }

        backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
        MHBVariableBlurDebug.log(
            "didMoveToWindow scale=\(MHBVariableBlurDebug.format(window.traitCollection.displayScale)), filtersCountBeforeReconfigure=\(backdropLayer.filters?.count ?? 0)"
        )

        reconfigureForCurrentStateIfNeeded(reason: "didMoveToWindow")
    }

    func updateConfiguration(
        maxBlurRadius: CGFloat,
        direction: MHBVariableBlurDirection,
        startOffset: CGFloat
    ) {
        let changed = currentMaxBlurRadius != maxBlurRadius
            || currentDirection != direction
            || currentStartOffset != startOffset

        MHBVariableBlurDebug.log(
            "updateConfiguration changed=\(changed), oldRadius=\(MHBVariableBlurDebug.format(currentMaxBlurRadius)), newRadius=\(MHBVariableBlurDebug.format(maxBlurRadius)), oldDirection=\(currentDirection.rawValue), newDirection=\(direction.rawValue), oldStartOffset=\(MHBVariableBlurDebug.format(currentStartOffset)), newStartOffset=\(MHBVariableBlurDebug.format(startOffset))"
        )

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

    private func reconfigureForCurrentStateIfNeeded(reason: String) {
        guard window != nil else {
            MHBVariableBlurDebug.log("reconfigure skipped reason=\(reason), windowExists=false")
            return
        }

        guard bounds.width > 0, bounds.height > 0 else {
            MHBVariableBlurDebug.log(
                "reconfigure skipped reason=\(reason), bounds=\(MHBVariableBlurDebug.format(bounds))"
            )
            return
        }

        let filtersCount = subviews.first?.layer.filters?.count ?? 0
        let needsReconfigure = bounds != lastConfiguredBounds || filtersCount != 1

        MHBVariableBlurDebug.log(
            "reconfigure check reason=\(reason), needsReconfigure=\(needsReconfigure), bounds=\(MHBVariableBlurDebug.format(bounds)), lastConfiguredBounds=\(MHBVariableBlurDebug.format(lastConfiguredBounds)), filtersCount=\(filtersCount)"
        )

        guard needsReconfigure else {
            return
        }

        lastConfiguredBounds = bounds
        configureVariableBlur(
            maxBlurRadius: currentMaxBlurRadius,
            direction: currentDirection,
            startOffset: currentStartOffset
        )

        MHBVariableBlurDebug.log(
            "reconfigure finished reason=\(reason), filtersCountAfter=\(subviews.first?.layer.filters?.count ?? 0)"
        )
    }

    private func configureVariableBlur(
        maxBlurRadius: CGFloat,
        direction: MHBVariableBlurDirection,
        startOffset: CGFloat
    ) {
        MHBVariableBlurDebug.log(
            "configure start radius=\(MHBVariableBlurDebug.format(maxBlurRadius)), direction=\(direction.rawValue), startOffset=\(MHBVariableBlurDebug.format(startOffset)), subviews=\(subviews.count), bounds=\(MHBVariableBlurDebug.format(bounds))"
        )

        let filterClassName = String("retliFAC".reversed())

        guard
            let filterClass = NSClassFromString(filterClassName) as? NSObject.Type,
            let filter = filterClass
                .perform(NSSelectorFromString(String(":epyThtiWretlif".reversed())), with: "variableBlur")?
                .takeUnretainedValue() as? NSObject
        else {
            MHBVariableBlurDebug.log("configure failed filterClassName=\(filterClassName), fallback=clearStandardEffectLayers")
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
        let oldFiltersCount = backdropLayer?.filters?.count ?? 0
        backdropLayer?.filters = [filter]
        let newFiltersCount = backdropLayer?.filters?.count ?? 0
        MHBVariableBlurDebug.log(
            "configure applied backdropLayerExists=\(backdropLayer != nil), oldFilters=\(oldFiltersCount), newFilters=\(newFiltersCount), backdropOpacity=\(MHBVariableBlurDebug.format(CGFloat(backdropLayer?.opacity ?? 0)))"
        )
        clearStandardEffectLayers()
    }

    private func clearStandardEffectLayers() {
        MHBVariableBlurDebug.log("clearStandardEffectLayers hiddenSubviews=\(subviews.dropFirst().count), allSubviews=\(subviews.count)")

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
            MHBVariableBlurDebug.log(
                "makeMask solid width=\(MHBVariableBlurDebug.format(width)), height=\(MHBVariableBlurDebug.format(height)), direction=\(direction.rawValue)"
            )
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

        MHBVariableBlurDebug.log(
            "makeMask gradient width=\(MHBVariableBlurDebug.format(width)), height=\(MHBVariableBlurDebug.format(height)), direction=\(direction.rawValue), startOffset=\(MHBVariableBlurDebug.format(startOffset)), point0=\(MHBVariableBlurDebug.format(gradientFilter.point0)), point1=\(MHBVariableBlurDebug.format(gradientFilter.point1)), output=\(output.width)x\(output.height)"
        )

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

        MHBVariableBlurDebug.log("makeMask solid output=\(output.width)x\(output.height)")

        return output
    }
}

// MHBVariableBlurDebug 可变模糊临时诊断
// 核心职责：
// - 统一输出首页头图模糊实验的临时控制台日志
// - 帮助判断 SwiftUI 参数、UIKit 生命周期和 CAFilter 配置是否生效
private enum MHBVariableBlurDebug {
    static func log(_ message: String) {
        #if DEBUG
        print("[DEBUG:HomeHeroBlur] \(message)")
        #endif
    }

    static func format(_ value: CGFloat) -> String {
        String(format: "%.3f", Double(value))
    }

    static func format(_ point: CGPoint) -> String {
        "x=\(format(point.x)),y=\(format(point.y))"
    }

    static func format(_ rect: CGRect) -> String {
        "x=\(format(rect.minX)),y=\(format(rect.minY)),w=\(format(rect.width)),h=\(format(rect.height))"
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
