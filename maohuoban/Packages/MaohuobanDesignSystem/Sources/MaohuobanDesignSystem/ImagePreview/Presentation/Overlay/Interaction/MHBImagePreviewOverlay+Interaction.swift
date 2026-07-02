import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MHBImagePreviewOverlay 交互与动画扩展
// 核心职责：
// - 拖拽关闭手势、Hero 动画、全屏展现与收起
// - 缩放驱动的 Chrome 显隐控制
extension MHBImagePreviewOverlay {
    // MARK: - Chrome 显隐控制

    func setChromeForcedHiddenByZoom(_ hidden: Bool) {
        guard isChromeForcedHiddenByZoom != hidden else { return }

        withTransaction(Transaction(animation: nil)) {
            isChromeForcedHiddenByZoom = hidden
            controlsOpacity = hidden ? 0 : (isChromeVisible ? 1 : 0)
        }
    }

    func syncZoomDrivenChromeVisibility(for state: MHBImagePreviewZoomState?) {
        let shouldHide = state?.isIdentityZoom == false
        setChromeForcedHiddenByZoom(shouldHide)
    }

    // MARK: - 交互手势

    var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                guard isDismissing == false else { return }
                guard allowsInteractiveDismissGesture else { return }

                switch interactiveDismissAxisLock {
                case .undecided:
                    let translation = value.translation
                    guard abs(translation.width) > 4 || abs(translation.height) > 4 else { return }
                    if translation.height > 0, abs(translation.height) > abs(translation.width) {
                        interactiveDismissAxisLock = .vertical
                    } else {
                        interactiveDismissAxisLock = .horizontal
                        return
                    }
                case .horizontal:
                    return
                case .vertical:
                    break
                }

                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    dragOffset = CGSize(
                        width: value.translation.width * 0.18,
                        height: max(value.translation.height, 0)
                    )
                }
            }
            .onEnded { value in
                guard isDismissing == false else { return }
                let axisLock = interactiveDismissAxisLock

                guard axisLock == .vertical else {
                    interactiveDismissAxisLock = .undecided
                    dragOffset = .zero
                    return
                }

                let predictedHeight = max(value.translation.height, value.predictedEndTranslation.height)

                if predictedHeight > dismissThreshold {
                    requestDismiss()
                } else {
                    interactiveDismissAxisLock = .undecided
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - 交互派生状态

    var dismissThreshold: CGFloat {
        max(baseFullscreenFrame(
            for: resolvedImageSize(for: session.currentAsset, fallback: overlayFrameInWindow.size),
            in: overlayFrameInWindow.size,
            safeAreaTop: overlaySafeAreaTop
        ).height * 0.28, 140)
    }

    var dismissProgress: CGFloat {
        guard dismissThreshold > 0.5 else { return 0 }
        return min(max(dragOffset.height / dismissThreshold, 0), 1)
    }

    var fullscreenDismissScale: CGFloat {
        let easedProgress = pow(dismissProgress, 0.85)
        return max(0.68, 1 - easedProgress * 0.32)
    }

    var isInteractiveDismissGestureActive: Bool {
        interactiveDismissAxisLock == .vertical && dragOffset.height > 0.5
    }

    var interactiveBackgroundFadeProgress: CGFloat {
        resolveInteractiveBackgroundFadeProgress(for: dragOffset.height)
    }

    var displayedBackgroundOpacity: Double {
        if isInteractiveDismissGestureActive {
            return resolveDisplayedBackgroundOpacity(for: dragOffset.height)
        }
        return backgroundOpacity
    }

    var shouldFreezeFullscreenPaging: Bool {
        allowsFullscreenPaging == false
    }

    // MARK: - 展现与收起动画

    func startPresentationIfNeeded(containerSize: CGSize, safeAreaTop: CGFloat) {
        guard hasStartedPresentation == false else { return }
        hasStartedPresentation = true

        let launchFrame = localSourceFrame(from: session.initialSource?.frameInWindow)
            ?? fallbackLaunchFrame(in: containerSize)
        let imageSize = resolvedImageSize(for: session.currentAsset, fallback: launchFrame.size)
        let targetFrame = MHBImagePreviewLayoutMetrics.fullscreenMediaFrame(
            for: imageSize,
            in: containerSize,
            safeAreaTop: safeAreaTop
        )

        heroFrame = launchFrame
        heroImageFrame = aspectFillFrame(for: imageSize, in: launchFrame)
        heroCornerRadius = session.initialSource?.cornerRadius ?? 0
        dragOffset = .zero
        fullscreenOpacity = 0
        fullscreenBridgeOpacity = 0
        controlsOpacity = 0
        heroOpacity = 1
        backgroundOpacity = 0
        isChromeVisible = true

        animationTask?.cancel()
        animationTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.18)) {
                backgroundOpacity = 1
            }
            withAnimation(.timingCurve(0.22, 0.88, 0.24, 1, duration: 0.32)) {
                heroFrame = targetFrame
                heroImageFrame = targetFrame
                heroCornerRadius = 0
            }

            try? await Task.sleep(for: .milliseconds(120))
            guard Task.isCancelled == false else { return }

            withTransaction(Transaction(animation: nil)) {
                fullscreenBridgeOpacity = 1
                heroOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(16))
            guard Task.isCancelled == false else { return }

            withTransaction(Transaction(animation: nil)) {
                fullscreenOpacity = 1
                controlsOpacity = isChromeVisible ? 1 : 0
            }

            try? await Task.sleep(for: .milliseconds(32))
            guard Task.isCancelled == false else { return }

            withTransaction(Transaction(animation: nil)) {
                fullscreenBridgeOpacity = 0
            }
        }
    }

    func dismissByButton() {
        requestDismiss()
    }

    func toggleChrome() {
        guard currentZoomState?.isIdentityZoom != false else { return }

        withTransaction(Transaction(animation: nil)) {
            isChromeVisible.toggle()
            controlsOpacity = isChromeVisible ? 1 : 0
        }
    }

    func requestDismiss() {
        guard isDismissing == false else { return }
        isDismissing = true
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            session.syncActiveIndexToExternalSelection()
            try? await Task.sleep(for: .milliseconds(32))
            guard Task.isCancelled == false else { return }

            let sourceID = session.sourceID(for: session.activeIndex)
            let resolution = resolveDismissTarget(for: sourceID)
            guard Task.isCancelled == false else { return }

            let fullscreenFrame = currentInteractiveFullscreenFrame(
                for: resolution.mediaSize,
                in: overlayFrameInWindow.size,
                safeAreaTop: overlaySafeAreaTop
            )

            withTransaction(Transaction(animation: nil)) {
                controlsOpacity = 0
            }

            withTransaction(Transaction(animation: nil)) {
                heroFrame = fullscreenFrame
                heroImageFrame = fullscreenFrame
                heroCornerRadius = 0
                heroOpacity = 1
                fullscreenBridgeOpacity = 0
                fullscreenOpacity = 0
            }

            withAnimation(.timingCurve(0.26, 0.82, 0.24, 1, duration: 0.30)) {
                heroFrame = resolution.targetFrame
                heroImageFrame = aspectFillFrame(for: resolution.mediaSize, in: resolution.targetFrame)
                heroCornerRadius = resolution.targetCornerRadius
                dragOffset = .zero
                backgroundOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(300))
            guard Task.isCancelled == false else { return }

            withTransaction(Transaction(animation: nil)) {
                heroOpacity = 0
                interactiveDismissAxisLock = .undecided
            }
            onDismissCompleted()
        }
    }

    // MARK: - 交互背景透明度

    func resolveInteractiveBackgroundFadeProgress(for dragHeight: CGFloat) -> CGFloat {
        let viewportHeight = max(overlayViewportFrame.height, 1)
        let fadeDistance = max(viewportHeight * 0.18, 1)
        return min(max(dragHeight / fadeDistance, 0), 1)
    }

    func resolveDisplayedBackgroundOpacity(for dragHeight: CGFloat) -> Double {
        let fadeProgress = Double(resolveInteractiveBackgroundFadeProgress(for: dragHeight))
        let resolvedOpacity = backgroundOpacity * (1 - fadeProgress * 0.92)
        return max(0, resolvedOpacity)
    }

    // MARK: - 几何辅助

    func baseFullscreenFrame(
        for imageSize: CGSize,
        in containerSize: CGSize,
        safeAreaTop: CGFloat
    ) -> CGRect {
        MHBImagePreviewLayoutMetrics.fullscreenMediaFrame(
            for: imageSize,
            in: containerSize,
            safeAreaTop: safeAreaTop
        )
    }

    func currentInteractiveFullscreenFrame(
        for imageSize: CGSize,
        in containerSize: CGSize,
        safeAreaTop: CGFloat
    ) -> CGRect {
        let baseFrame = baseFullscreenFrame(
            for: imageSize,
            in: containerSize,
            safeAreaTop: safeAreaTop
        )
        let scale = fullscreenDismissScale
        let scaledSize = CGSize(width: baseFrame.width * scale, height: baseFrame.height * scale)

        return CGRect(
            x: baseFrame.midX - scaledSize.width / 2 + (dragOffset.width * 0.18),
            y: baseFrame.midY - scaledSize.height / 2 + dragOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    func localSourceFrame(from frameInWindow: CGRect?) -> CGRect? {
        guard let frameInWindow,
              frameInWindow.isEmpty == false,
              frameInWindow.isNull == false else {
            return nil
        }

        let viewport = overlayViewportFrame
        return CGRect(
            x: frameInWindow.minX - viewport.minX,
            y: frameInWindow.minY - viewport.minY,
            width: frameInWindow.width,
            height: frameInWindow.height
        )
    }
}
