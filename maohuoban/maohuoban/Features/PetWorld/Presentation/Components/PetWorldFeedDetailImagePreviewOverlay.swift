import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetWorldFeedDetailImagePreviewOverlay 详情页大图预览层
// 核心职责：
// - 承载主图到全屏预览的 Hero 动画
// - 提供全屏分页浏览、关闭和回落动画
struct PetWorldFeedDetailImagePreviewOverlay: View {
    let mediaItems: [PetWorldFeedDetailMedia]
    @Binding var selectedIndex: Int
    let sourceFrameInGlobal: CGRect
    let sourceCornerRadius: CGFloat
    let onDismissCompleted: () -> Void

    @State private var overlayFrameInGlobal = CGRect.zero
    @State private var heroFrame = CGRect.zero
    @State private var heroImageFrame = CGRect.zero
    @State private var heroCornerRadius: CGFloat = 0
    @State private var heroOpacity = 1.0
    @State private var backgroundOpacity = 0.0
    @State private var fullscreenOpacity = 0.0
    @State private var controlsOpacity = 0.0
    @State private var hasStartedPresentation = false
    @State private var isDismissing = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size

            ZStack(alignment: .top) {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                fullscreenPager(containerSize: containerSize)
                    .opacity(fullscreenOpacity)
                    .allowsHitTesting(fullscreenOpacity > 0.99 && !isDismissing)

                heroLayer(containerSize: containerSize)

                topBar()
                    .padding(.top, max(geometry.safeAreaInsets.top, MHBTheme.Spacing.s3))
                    .opacity(controlsOpacity)
                    .allowsHitTesting(controlsOpacity > 0.9 && !isDismissing)
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .ignoresSafeArea()
            .statusBarHidden(controlsOpacity < 0.9)
            .onAppear {
                overlayFrameInGlobal = geometry.frame(in: .global)
                startPresentationIfNeeded(containerSize: containerSize)
            }
            .onDisappear {
                animationTask?.cancel()
            }
        }
    }

    private func fullscreenPager(containerSize: CGSize) -> some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, mediaItem in
                Image(mediaItem.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: containerSize.width, height: containerSize.height)
                    .tag(index)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggleControls)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(MHBPagedScrollBounceDisabler())
    }

    @ViewBuilder
    private func heroLayer(containerSize: CGSize) -> some View {
        if hasStartedPresentation, heroOpacity > 0.001, let mediaItem = selectedMediaItem {
            Image(mediaItem.assetName)
                .resizable()
                .scaledToFill()
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

    private func topBar() -> some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button(action: requestDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("关闭大图预览")

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text(pageIndicatorText)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(height: 40)
                .glassEffect(.regular, in: .capsule)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
    }

    private var selectedMediaItem: PetWorldFeedDetailMedia? {
        guard mediaItems.indices.contains(selectedIndex) else {
            return mediaItems.first
        }

        return mediaItems[selectedIndex]
    }

    private var pageIndicatorText: String {
        "\(min(selectedIndex + 1, mediaItems.count))/\(mediaItems.count)"
    }

    private func startPresentationIfNeeded(containerSize: CGSize) {
        guard !hasStartedPresentation else {
            return
        }

        hasStartedPresentation = true
        let launchFrame = localSourceFrame() ?? fallbackLaunchFrame(in: containerSize)
        let imageSize = selectedImageSize(fallback: launchFrame.size)
        let targetFrame = Self.aspectFitFrame(
            for: imageSize,
            in: CGRect(origin: .zero, size: containerSize)
        )

        heroFrame = launchFrame
        heroImageFrame = Self.aspectFillFrame(for: imageSize, in: launchFrame)
        heroCornerRadius = sourceCornerRadius
        backgroundOpacity = 0
        fullscreenOpacity = 0
        controlsOpacity = 0
        heroOpacity = 1

        animationTask?.cancel()
        animationTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.18)) {
                backgroundOpacity = 1
            }

            withAnimation(PetWorldFeedDetailLayout.previewPresentationAnimation) {
                heroFrame = targetFrame
                heroImageFrame = targetFrame
                heroCornerRadius = 0
            }

            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }

            withTransaction(Transaction(animation: nil)) {
                fullscreenOpacity = 1
                heroOpacity = 0
            }

            withAnimation(.easeInOut(duration: 0.16)) {
                controlsOpacity = 1
            }
        }
    }

    private func requestDismiss() {
        guard !isDismissing else {
            return
        }

        isDismissing = true
        animationTask?.cancel()

        let currentFrame = currentFullscreenFrame()
        let targetFrame = localSourceFrame() ?? fallbackLaunchFrame(in: overlayFrameInGlobal.size)
        let imageSize = selectedImageSize(fallback: targetFrame.size)

        withTransaction(Transaction(animation: nil)) {
            controlsOpacity = 0
            fullscreenOpacity = 0
            heroFrame = currentFrame
            heroImageFrame = currentFrame
            heroCornerRadius = 0
            heroOpacity = 1
        }

        animationTask = Task { @MainActor in
            withAnimation(PetWorldFeedDetailLayout.previewDismissAnimation) {
                heroFrame = targetFrame
                heroImageFrame = Self.aspectFillFrame(for: imageSize, in: targetFrame)
                heroCornerRadius = sourceCornerRadius
                backgroundOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            onDismissCompleted()
        }
    }

    private func toggleControls() {
        guard !isDismissing else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            controlsOpacity = controlsOpacity > 0.5 ? 0 : 1
        }
    }

    private func localSourceFrame() -> CGRect? {
        guard !sourceFrameInGlobal.isEmpty, !sourceFrameInGlobal.isNull else {
            return nil
        }

        return sourceFrameInGlobal.offsetBy(
            dx: -overlayFrameInGlobal.minX,
            dy: -overlayFrameInGlobal.minY
        )
    }

    private func fallbackLaunchFrame(in containerSize: CGSize) -> CGRect {
        CGRect(
            x: containerSize.width / 2 - 36,
            y: containerSize.height / 2 - 36,
            width: 72,
            height: 72
        )
    }

    private func currentFullscreenFrame() -> CGRect {
        Self.aspectFitFrame(
            for: selectedImageSize(fallback: overlayFrameInGlobal.size),
            in: CGRect(origin: .zero, size: overlayFrameInGlobal.size)
        )
    }

    private func selectedImageSize(fallback: CGSize) -> CGSize {
        guard let assetName = selectedMediaItem?.assetName,
              let image = UIImage(named: assetName),
              image.size.width > 0,
              image.size.height > 0
        else {
            return fallback
        }

        return image.size
    }

    private static func aspectFitFrame(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0.5, imageSize.height > 0.5 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private static func aspectFillFrame(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0.5, imageSize.height > 0.5 else {
            return bounds
        }

        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let filledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - filledSize.width / 2,
            y: bounds.midY - filledSize.height / 2,
            width: filledSize.width,
            height: filledSize.height
        )
    }
}
