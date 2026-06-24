import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MHBImagePreviewOverlay 图片预览全屏层
// 核心职责：
// - 承载自定义 Hero 动画、全屏翻页与关闭交互
// - 在 source 与全屏画面之间接管展示时序，规避系统转场跳点
struct MHBImagePreviewOverlay: View {
    let session: MHBImagePreviewSession
    let coordinator: MHBImagePreviewCoordinator
    let onDismissCompleted: @MainActor () -> Void

    @State var overlayFrameInWindow: CGRect = .zero
    @State var geometryFrameInWindow: CGRect = .zero
    @State var heroFrame: CGRect = .zero
    @State var heroImageFrame: CGRect = .zero
    @State var heroCornerRadius: CGFloat = 0
    @State var heroOpacity = 1.0
    @State var backgroundOpacity = 0.0
    @State var fullscreenOpacity = 0.0
    @State var fullscreenBridgeOpacity = 0.0
    @State var controlsOpacity = 0.0
    @State var scrollPosition: Int?
    @State var dragOffset: CGSize = .zero
    @State var hasStartedPresentation = false
    @State var isDismissing = false
    @State var isChromeVisible = true
    @State var animationTask: Task<Void, Never>?
    @State var interactiveDismissAxisLock: MHBImagePreviewDragAxisLock = .undecided
    @State var overlaySafeAreaTop: CGFloat = 0
    @State var zoomStates: [Int: MHBImagePreviewZoomState] = [:]
    @State var isChromeForcedHiddenByZoom = false
#if canImport(UIKit)
    @State var assetImages: [String: UIImage] = [:]
    @State var backdropSnapshotImage: UIImage?
#endif

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
}
