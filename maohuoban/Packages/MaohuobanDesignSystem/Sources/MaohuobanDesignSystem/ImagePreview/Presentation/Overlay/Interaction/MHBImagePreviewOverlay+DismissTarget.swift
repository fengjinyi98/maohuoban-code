import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MHBImagePreviewOverlay 关闭目标解析扩展
// 核心职责：
// - 承载关闭回落动画时的 source 查找与 fallback 策略
extension MHBImagePreviewOverlay {
    func resolveDismissTarget(for sourceID: MHBImagePreviewSourceID) -> MHBImagePreviewDismissTarget {
        if let readySource = readyDismissSource(for: sourceID) {
            return makeDismissTarget(from: readySource)
        }

        if let fallbackSource = coordinator.source(for: sourceID) {
            return makeDismissTarget(from: fallbackSource)
        }

        if let fallbackSource = session.initialSource {
            return makeDismissTarget(
                from: fallbackSource,
                preferredAsset: session.currentAsset
            )
        }

        let fallbackFrame = fallbackLaunchFrame(in: overlayFrameInWindow.size)
        let mediaSize = resolvedImageSize(for: session.currentAsset, fallback: fallbackFrame.size)
        return MHBImagePreviewDismissTarget(
            targetFrame: fallbackFrame,
            targetCornerRadius: 0,
            mediaSize: mediaSize
        )
    }

    func readyDismissSource(for sourceID: MHBImagePreviewSourceID) -> MHBImagePreviewSourceRegistration? {
        guard let source = coordinator.source(for: sourceID) else {
            return nil
        }
        return isDismissTargetVisible(source.frameInWindow) ? source : nil
    }

    func isDismissTargetVisible(_ frameInWindow: CGRect) -> Bool {
        guard frameInWindow.isEmpty == false,
              frameInWindow.isNull == false else {
            return false
        }

        let viewport = overlayViewportFrame
        guard viewport.isEmpty == false, viewport.isNull == false else {
            return true
        }

        let intersection = frameInWindow.intersection(viewport)
        return intersection.isEmpty == false
            && intersection.isNull == false
            && intersection.width > 8
            && intersection.height > 8
    }

    func makeDismissTarget(from source: MHBImagePreviewSourceRegistration) -> MHBImagePreviewDismissTarget {
        makeDismissTarget(from: source, preferredAsset: source.asset)
    }

    func makeDismissTarget(
        from source: MHBImagePreviewSourceRegistration,
        preferredAsset: MHBImagePreviewAsset?
    ) -> MHBImagePreviewDismissTarget {
        MHBImagePreviewDismissTarget(
            targetFrame: localSourceFrame(from: source.frameInWindow) ?? fallbackLaunchFrame(in: overlayFrameInWindow.size),
            targetCornerRadius: source.cornerRadius,
            mediaSize: resolvedImageSize(for: preferredAsset, fallback: source.frameInWindow.size)
        )
    }
}
