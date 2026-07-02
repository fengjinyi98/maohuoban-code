import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MHBImagePreviewOverlay 状态管理扩展
// 核心职责：
// - 承载预览层的派生展示状态计算
// - 纯函数几何辅助方法
extension MHBImagePreviewOverlay {
    var shouldDisplayChrome: Bool {
        isChromeVisible
            && isChromeForcedHiddenByZoom == false
            && isInteractiveDismissGestureActive == false
            && isDismissing == false
    }

    var displayedControlsOpacity: Double {
        shouldDisplayChrome ? controlsOpacity : 0
    }

    var currentZoomState: MHBImagePreviewZoomState? {
        zoomStates[session.activeIndex]
    }

    var allowsFullscreenPaging: Bool {
        MHBImagePreviewInteractionPolicy.allowsPaging(
            currentAsset: session.currentAsset,
            currentZoomState: currentZoomState,
            isDismissing: isDismissing,
            isInteractiveDismissing: interactiveDismissAxisLock == .vertical
        )
    }

    var allowsInteractiveDismissGesture: Bool {
        MHBImagePreviewInteractionPolicy.allowsDismissGesture(
            currentAsset: session.currentAsset,
            currentZoomState: currentZoomState,
            isDismissing: isDismissing
        )
    }

    var overlayViewportFrame: CGRect {
        if overlayFrameInWindow.isEmpty == false {
            return overlayFrameInWindow
        }
        return geometryFrameInWindow
    }

    func effectiveContainerSize(from geometry: GeometryProxy) -> CGSize {
        let resolved = resolvedOverlayFrame(from: geometry)
        guard resolved.width > 0.5, resolved.height > 0.5 else {
            return geometry.size
        }
        return resolved.size
    }

    func resolvedOverlayFrame(from geometry: GeometryProxy) -> CGRect {
#if canImport(UIKit)
        if let window = Self.activeKeyWindow() {
            return window.bounds
        }
#endif
        return geometry.frame(in: .global)
    }

    func resolvedImageSize(
        for asset: MHBImagePreviewAsset?,
        fallback: CGSize
    ) -> CGSize {
        asset?.pixelSize ?? fallback
    }

    func aspectFillFrame(
        for imageSize: CGSize,
        in bounds: CGRect
    ) -> CGRect {
        guard imageSize.width > 0.5, imageSize.height > 0.5 else {
            return bounds
        }

        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let filledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: bounds.midX - filledSize.width / 2,
            y: bounds.midY - filledSize.height / 2,
            width: filledSize.width,
            height: filledSize.height
        )
    }

    func fallbackLaunchFrame(in containerSize: CGSize) -> CGRect {
        CGRect(
            x: containerSize.width * 0.2,
            y: containerSize.height * 0.35,
            width: containerSize.width * 0.6,
            height: containerSize.width * 0.6
        )
    }

#if canImport(UIKit)
    static func activeKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
#endif
}
