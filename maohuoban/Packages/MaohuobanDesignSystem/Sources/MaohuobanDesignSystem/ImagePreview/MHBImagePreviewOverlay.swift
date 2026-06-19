import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MHBImagePreviewDismissTarget 图片预览关闭目标
// 核心职责：
// - 承载关闭时回落到哪个 source 的解析结果
// - 为 Hero 回落动画提供目标 frame、圆角与图片尺寸
private struct MHBImagePreviewDismissTarget {
    let targetFrame: CGRect
    let targetCornerRadius: CGFloat
    let mediaSize: CGSize
}

// MHBImagePreviewDragAxisLock 预览拖拽轴锁
// 核心职责：
// - 在用户开始下拉关闭后锁定为纵向拖拽
// - 阻断同一手势序列继续触发横向分页切图
private enum MHBImagePreviewDragAxisLock {
    case undecided
    case horizontal
    case vertical
}

// MHBImagePreviewOverlay 图片预览全屏层
// 核心职责：
// - 承载自定义 Hero 动画、全屏翻页与关闭交互
// - 在 source 与全屏画面之间接管展示时序，规避系统转场跳点
struct MHBImagePreviewOverlay: View {
    let session: MHBImagePreviewSession
    let coordinator: MHBImagePreviewCoordinator
    let onDismissCompleted: @MainActor () -> Void

    @State private var overlayFrameInWindow: CGRect = .zero
    @State private var geometryFrameInWindow: CGRect = .zero
    @State private var heroFrame: CGRect = .zero
    @State private var heroImageFrame: CGRect = .zero
    @State private var heroCornerRadius: CGFloat = 0
    @State private var heroOpacity = 1.0
    @State private var backgroundOpacity = 0.0
    @State private var fullscreenOpacity = 0.0
    @State private var fullscreenBridgeOpacity = 0.0
    @State private var controlsOpacity = 0.0
    @State private var scrollPosition: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var hasStartedPresentation = false
    @State private var isDismissing = false
    @State private var isChromeVisible = true
    @State private var animationTask: Task<Void, Never>?
    @State private var interactiveDismissAxisLock: MHBImagePreviewDragAxisLock = .undecided
    @State private var overlaySafeAreaTop: CGFloat = 0
    @State private var zoomStates: [Int: MHBImagePreviewZoomState] = [:]
    @State private var isChromeForcedHiddenByZoom = false
    // Overlay 渲染专用 UIImage 缓存
    // 后台解码完成后一次性回主线程赋值，渲染只经 Image(uiImage:).resizable() 路径
    // 资源尺寸由 MHBImagePreviewAsset.pixelSize 直接提供，无需再探测 UIImage
#if canImport(UIKit)
    @State private var assetImages: [String: UIImage] = [:]
    @State private var backdropSnapshotImage: UIImage?
#endif

    private var shouldDisplayChrome: Bool {
        isChromeVisible
            && isChromeForcedHiddenByZoom == false
            && isInteractiveDismissGestureActive == false
            && isDismissing == false
    }

    private var displayedControlsOpacity: Double {
        shouldDisplayChrome ? controlsOpacity : 0
    }

    private var currentZoomState: MHBImagePreviewZoomState? {
        zoomStates[session.activeIndex]
    }

    private var allowsFullscreenPaging: Bool {
        MHBImagePreviewInteractionPolicy.allowsPaging(
            currentAsset: session.currentAsset,
            currentZoomState: currentZoomState,
            isDismissing: isDismissing,
            isInteractiveDismissing: interactiveDismissAxisLock == .vertical
        )
    }

    private var allowsInteractiveDismissGesture: Bool {
        MHBImagePreviewInteractionPolicy.allowsDismissGesture(
            currentAsset: session.currentAsset,
            currentZoomState: currentZoomState,
            isDismissing: isDismissing
        )
    }

    private func setChromeForcedHiddenByZoom(_ hidden: Bool) {
        guard isChromeForcedHiddenByZoom != hidden else { return }

        withTransaction(Transaction(animation: nil)) {
            isChromeForcedHiddenByZoom = hidden
            controlsOpacity = hidden ? 0 : (isChromeVisible ? 1 : 0)
        }
    }

    private func syncZoomDrivenChromeVisibility(for state: MHBImagePreviewZoomState?) {
        let shouldHide = state?.isIdentityZoom == false
        setChromeForcedHiddenByZoom(shouldHide)
    }

    var body: some View {
        GeometryReader { geometry in
            let containerSize = effectiveContainerSize(from: geometry)
            let safeAreaTop = geometry.safeAreaInsets.top

            ZStack(alignment: .top) {
                backdropLayer(containerSize: containerSize)

                Color.black
                    .opacity(displayedBackgroundOpacity)
                    .ignoresSafeArea()

                fullscreenContent(containerSize: containerSize)
                    .frame(width: containerSize.width, height: containerSize.height)
                    .scaleEffect(fullscreenDismissScale, anchor: .center)
                    .offset(x: dragOffset.width * 0.18, y: dragOffset.height)
                    .opacity(fullscreenOpacity)
                    .allowsHitTesting(fullscreenOpacity > 0.99 && fullscreenBridgeOpacity < 0.01 && isDismissing == false)
                    .simultaneousGesture(dismissGesture)

                fullscreenBridgeLayer(containerSize: containerSize)

                heroLayer(containerSize: containerSize)

                topBar()
                    .mhbTopChromeAligned(geometrySafeAreaTop: safeAreaTop)
                    .opacity(displayedControlsOpacity)
                    .allowsHitTesting(shouldDisplayChrome)
            }
            .ignoresSafeArea()
            .frame(width: containerSize.width, height: containerSize.height)
            .statusBarHidden(!shouldDisplayChrome)
            .onAppear {
                let geometryFrame = geometry.frame(in: .global)
                let overlayFrame = resolvedOverlayFrame(from: geometry)

                geometryFrameInWindow = geometryFrame
                overlayFrameInWindow = overlayFrame
                overlaySafeAreaTop = safeAreaTop
                scrollPosition = session.activeIndex
                isChromeForcedHiddenByZoom = false
#if canImport(UIKit)
                if backdropSnapshotImage == nil,
                   let data = session.backdropSnapshotData {
                    backdropSnapshotImage = UIImage(data: data)
                }
#endif
                startPreloadAssets()
                startPresentationIfNeeded(
                    containerSize: containerSize,
                    safeAreaTop: safeAreaTop
                )
            }
            .onDisappear {
                animationTask?.cancel()
            }
        }
    }

    private func topBar() -> some View {
        HStack(spacing: 12) {
            Button(action: dismissByButton) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("关闭大图预览")

            Spacer(minLength: 12)

            Button(action: {}) {
                Text(session.pageIndicatorText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: .capsule)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func backdropLayer(containerSize: CGSize) -> some View {
#if canImport(UIKit)
        if let backdropSnapshotImage {
            Image(uiImage: backdropSnapshotImage)
                .resizable()
                .scaledToFill()
                .frame(width: containerSize.width, height: containerSize.height)
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
#endif
    }

    @ViewBuilder
    private func heroLayer(containerSize: CGSize) -> some View {
        // 首帧 heroFrame/heroImageFrame 还是 .zero，onAppear 尚未跑
        // 此时渲染 hero 会让 SwiftUI 在 1×1 frame 上合成 mask 进入 offscreen 路径，导致主线程卡死
        // 必须等 startPresentationIfNeeded 把 frame 准备好之后再挂进视图树
        if hasStartedPresentation, heroOpacity > 0.001 {
            assetImage(for: session.currentAsset)
                .frame(width: max(heroImageFrame.width, 1), height: max(heroImageFrame.height, 1))
                .offset(
                    x: heroImageFrame.midX - heroFrame.midX,
                    y: heroImageFrame.midY - heroFrame.midY
                )
                .frame(width: max(heroFrame.width, 1), height: max(heroFrame.height, 1))
                .clipShape(.rect(cornerRadius: heroCornerRadius))
                .position(x: heroFrame.midX, y: heroFrame.midY)
                .frame(width: containerSize.width, height: containerSize.height)
                .opacity(heroOpacity)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func fullscreenBridgeLayer(containerSize: CGSize) -> some View {
        if fullscreenBridgeOpacity > 0.001 {
            let mediaSize = resolvedImageSize(for: session.currentAsset, fallback: containerSize)
            let mediaFrame = MHBImagePreviewLayoutMetrics.fullscreenMediaFrame(
                for: mediaSize,
                in: containerSize,
                safeAreaTop: overlaySafeAreaTop
            )

            assetImage(for: session.currentAsset)
                .frame(width: max(mediaFrame.width, 1), height: max(mediaFrame.height, 1))
                .position(x: mediaFrame.midX, y: mediaFrame.midY)
                .opacity(fullscreenBridgeOpacity)
                .allowsHitTesting(false)
        }
    }

    private func fullscreenContent(containerSize: CGSize) -> some View {
        ScrollView(.horizontal) {
            // LazyHStack 确保 ScrollView 只为当前与邻近 page 创建视图
            // 否则 N 张 5MB 巨图会同帧全部进入布局管线，把主线程打死
            LazyHStack(spacing: 0) {
                ForEach(Array(session.items.enumerated()), id: \.element.id) { index, asset in
                    fullscreenPage(
                        index: index,
                        asset: asset,
                        containerSize: containerSize
                    )
                    .frame(width: containerSize.width, height: containerSize.height)
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollDisabled(shouldFreezeFullscreenPaging)
        .scrollPosition(id: $scrollPosition)
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue else { return }
            guard shouldFreezeFullscreenPaging == false else {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    scrollPosition = session.activeIndex
                }
                return
            }
            session.updateActiveIndex(newValue)
        }
        .onChange(of: session.activeIndex) { _, newValue in
            syncZoomDrivenChromeVisibility(for: zoomStates[newValue])
            guard shouldFreezeFullscreenPaging == false else { return }
            guard scrollPosition != newValue else { return }
            scrollPosition = newValue
        }
    }

    // fullscreenPage 全屏单页
    // 核心职责：
    // - 以预解码 UIImage + 手算 aspectFit 尺寸渲染
    // - 禁用 SwiftUI Image.aspectRatio，避免巨幅 Asset 在布局路径反复触发解码
    @ViewBuilder
    private func fullscreenPage(
        index: Int,
        asset: MHBImagePreviewAsset,
        containerSize: CGSize
    ) -> some View {
#if canImport(UIKit)
        if let prefetchedImage = prefetchedImage(for: asset) {
            MHBImagePreviewZoomablePage(
                asset: asset,
                image: prefetchedImage,
                onSingleTap: toggleChrome,
                onWillZoomIn: {
                    handleZoomWillBegin(for: index)
                },
                onStateChange: { state in
                    handleZoomStateChange(state, for: index)
                }
            )
        } else {
            let mediaSize = resolvedImageSize(for: asset, fallback: containerSize)
            let mediaFrame = MHBImagePreviewLayoutMetrics.fullscreenMediaFrame(
                for: mediaSize,
                in: containerSize,
                safeAreaTop: overlaySafeAreaTop
            )

            ZStack {
                assetImage(for: asset)
                    .frame(width: max(mediaFrame.width, 1), height: max(mediaFrame.height, 1))
                    .position(x: mediaFrame.midX, y: mediaFrame.midY)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: toggleChrome)
        }
#else
        let mediaSize = resolvedImageSize(for: asset, fallback: containerSize)
        let mediaFrame = MHBImagePreviewLayoutMetrics.fullscreenMediaFrame(
            for: mediaSize,
            in: containerSize,
            safeAreaTop: overlaySafeAreaTop
        )

        ZStack {
            assetImage(for: asset)
                .frame(width: max(mediaFrame.width, 1), height: max(mediaFrame.height, 1))
                .position(x: mediaFrame.midX, y: mediaFrame.midY)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleChrome)
#endif
    }



    private var dismissGesture: some Gesture {
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

    private var dismissThreshold: CGFloat {
        // 绝对不能引用 fullscreenDismissScale / dismissProgress，否则
        // scaleEffect(fullscreenDismissScale) 在 body 里触发以下递归：
        //   scaleEffect → fullscreenDismissScale → dismissProgress
        //     → dismissThreshold → currentInteractiveFullscreenFrame
        //     → fullscreenDismissScale → … 栈溢出
        max(baseFullscreenFrame(
            for: resolvedImageSize(for: session.currentAsset, fallback: overlayFrameInWindow.size),
            in: overlayFrameInWindow.size,
            safeAreaTop: overlaySafeAreaTop
        ).height * 0.28, 140)
    }

    private var dismissProgress: CGFloat {
        guard dismissThreshold > 0.5 else { return 0 }
        return min(max(dragOffset.height / dismissThreshold, 0), 1)
    }

    private var fullscreenDismissScale: CGFloat {
        let easedProgress = pow(dismissProgress, 0.85)
        return max(0.68, 1 - easedProgress * 0.32)
    }

    private var isInteractiveDismissGestureActive: Bool {
        interactiveDismissAxisLock == .vertical && dragOffset.height > 0.5
    }

    private var interactiveBackgroundFadeProgress: CGFloat {
        resolveInteractiveBackgroundFadeProgress(for: dragOffset.height)
    }

    private var displayedBackgroundOpacity: Double {
        if isInteractiveDismissGestureActive {
            return resolveDisplayedBackgroundOpacity(for: dragOffset.height)
        }
        return backgroundOpacity
    }

    private var shouldFreezeFullscreenPaging: Bool {
        allowsFullscreenPaging == false
    }

    private func startPresentationIfNeeded(containerSize: CGSize, safeAreaTop: CGFloat) {
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

    private func dismissByButton() {
        requestDismiss()
    }

    private func toggleChrome() {
        guard currentZoomState?.isIdentityZoom != false else { return }

        withTransaction(Transaction(animation: nil)) {
            isChromeVisible.toggle()
            controlsOpacity = isChromeVisible ? 1 : 0
        }
    }

    private func requestDismiss() {
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

    private func resolveInteractiveBackgroundFadeProgress(for dragHeight: CGFloat) -> CGFloat {
        let viewportHeight = max(overlayViewportFrame.height, 1)
        let fadeDistance = max(viewportHeight * 0.18, 1)
        return min(max(dragHeight / fadeDistance, 0), 1)
    }

    private func resolveDisplayedBackgroundOpacity(for dragHeight: CGFloat) -> Double {
        let fadeProgress = Double(resolveInteractiveBackgroundFadeProgress(for: dragHeight))
        let resolvedOpacity = backgroundOpacity * (1 - fadeProgress * 0.92)
        return max(0, resolvedOpacity)
    }

    private func resolveDismissTarget(for sourceID: MHBImagePreviewSourceID) -> MHBImagePreviewDismissTarget {
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

    private func readyDismissSource(for sourceID: MHBImagePreviewSourceID) -> MHBImagePreviewSourceRegistration? {
        guard let source = coordinator.source(for: sourceID) else {
            return nil
        }
        return isDismissTargetVisible(source.frameInWindow) ? source : nil
    }

    private func isDismissTargetVisible(_ frameInWindow: CGRect) -> Bool {
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

    private func makeDismissTarget(from source: MHBImagePreviewSourceRegistration) -> MHBImagePreviewDismissTarget {
        makeDismissTarget(from: source, preferredAsset: source.asset)
    }

    private func makeDismissTarget(
        from source: MHBImagePreviewSourceRegistration,
        preferredAsset: MHBImagePreviewAsset?
    ) -> MHBImagePreviewDismissTarget {
        MHBImagePreviewDismissTarget(
            targetFrame: localSourceFrame(from: source.frameInWindow) ?? fallbackLaunchFrame(in: overlayFrameInWindow.size),
            targetCornerRadius: source.cornerRadius,
            mediaSize: resolvedImageSize(for: preferredAsset, fallback: source.frameInWindow.size)
        )
    }

    // 纯几何函数：只算 aspectFit 后的 frame，不引用 gesture 状态
    // 供 dismissThreshold / 动画动态 frame 共用，隔离 scale 引用避免成环
    private func baseFullscreenFrame(
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

    private var overlayViewportFrame: CGRect {
        if overlayFrameInWindow.isEmpty == false {
            return overlayFrameInWindow
        }
        return geometryFrameInWindow
    }

    private func effectiveContainerSize(from geometry: GeometryProxy) -> CGSize {
        let resolved = resolvedOverlayFrame(from: geometry)
        guard resolved.width > 0.5, resolved.height > 0.5 else {
            return geometry.size
        }
        return resolved.size
    }

    private func resolvedOverlayFrame(from geometry: GeometryProxy) -> CGRect {
#if canImport(UIKit)
        if let window = Self.activeKeyWindow() {
            return window.bounds
        }
#endif
        return geometry.frame(in: .global)
    }

    private func resolvedImageSize(
        for asset: MHBImagePreviewAsset?,
        fallback: CGSize
    ) -> CGSize {
        asset?.pixelSize ?? fallback
    }

    private func aspectFillFrame(
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

    private func currentInteractiveFullscreenFrame(
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

    private func localSourceFrame(from frameInWindow: CGRect?) -> CGRect? {
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

    private func fallbackLaunchFrame(in containerSize: CGSize) -> CGRect {
        CGRect(
            x: containerSize.width * 0.2,
            y: containerSize.height * 0.35,
            width: containerSize.width * 0.6,
            height: containerSize.width * 0.6
        )
    }

    private func handleZoomWillBegin(for index: Int) {
        guard index == session.activeIndex else { return }
        setChromeForcedHiddenByZoom(true)
    }

    private func handleZoomStateChange(_ state: MHBImagePreviewZoomState, for index: Int) {
        let previousState = zoomStates[index]
        if let previousState,
           previousState.isApproximatelyEqual(to: state) {
            return
        }

        zoomStates[index] = state

        if index == session.activeIndex {
            let previousIdentity = previousState?.isIdentityZoom
            if previousIdentity != state.isIdentityZoom {
                syncZoomDrivenChromeVisibility(for: state)
            }
        }
    }

#if canImport(UIKit)
    private func prefetchedImage(for asset: MHBImagePreviewAsset) -> UIImage? {
        assetImages[asset.sourceIdentifier]
    }
#endif


    // assetImage 渲染预览图
    // 核心职责：
    // - 以预解码 UIImage 生成 Image，禁用 aspectRatio 修饰
    // - 未加载完成时返回 Color.black 占位，避免主线程同步解码大图
    @ViewBuilder
    private func assetImage(for asset: MHBImagePreviewAsset?) -> some View {
#if canImport(UIKit)
        if let asset, let uiImage = assetImages[asset.sourceIdentifier] {
            Image(uiImage: uiImage)
                .resizable()
        } else if let asset {
            MHBImagePreviewAssetImage(
                asset: asset,
                contentMode: .fit,
                cornerRadius: 0
            )
        } else {
            Color.black
        }
#else
        Color.black
#endif
    }

    // 预览挂载时在后台解码 session.items 的 UIImage，完成后一次性回主线程
    // 尺寸从 asset.pixelSize 直接获得，这里只负责准备位图用于 Image(uiImage:) 渲染
    private func startPreloadAssets() {
#if canImport(UIKit)
        guard assetImages.isEmpty else { return }
        let items = session.items
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                var images: [String: UIImage] = [:]
                for item in items where images[item.sourceIdentifier] == nil {
                    let image: UIImage?
                    switch item.sourceKind {
                    case let .localAsset(name):
                        image = UIImage(named: name)
                    case let .remote(urlString):
                        if let url = URL(string: urlString) {
                            image = try? UIImage(data: Data(contentsOf: url))
                        } else {
                            image = nil
                        }
                    case .systemSymbol, .empty:
                        image = nil
                    }
                    guard let image else { continue }
                    _ = image.cgImage
                    images[item.sourceIdentifier] = image
                }
                return images
            }.value
            assetImages = result
        }
#endif
    }
}

#if canImport(UIKit)
private extension MHBImagePreviewOverlay {
    static func activeKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
#endif
