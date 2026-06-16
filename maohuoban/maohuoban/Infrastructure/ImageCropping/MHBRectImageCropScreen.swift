import SwiftUI
import MaohuobanDesignSystem
import UIKit

// MHBRectImageCropScreen 矩形图片裁剪页
// 核心职责：
// - 提供背景图片矩形裁剪交互，支持拖拽和缩放
// - 在确认后输出本地裁剪图片，供业务上传或临时预览
struct MHBRectImageCropScreen: View {
    let originalImage: UIImage
    let title: String
    let cropAspectRatio: CGFloat
    let onCancel: () -> Void
    let onSave: (UIImage) -> Void

    @State private var imageOffset: CGSize = .zero
    @State private var imageScale: CGFloat = 1
    @State private var tempOffset: CGSize = .zero
    @State private var tempScale: CGFloat = 1
    @State private var isInteracting = false
    @State private var windowSafeAreaInsets: UIEdgeInsets = .zero

    init(
        originalImage: UIImage,
        title: String = "裁剪背景",
        cropAspectRatio: CGFloat,
        onCancel: @escaping () -> Void,
        onSave: @escaping (UIImage) -> Void
    ) {
        self.originalImage = originalImage.mhb_normalizedForRectCropping()
        self.title = title
        self.cropAspectRatio = max(cropAspectRatio, 0.1)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let cropFrameSize = cropSize(for: viewportSize)
            let effectiveTopSafeArea = max(geometry.safeAreaInsets.top, windowSafeAreaInsets.top)
            let effectiveBottomSafeArea = max(geometry.safeAreaInsets.bottom, windowSafeAreaInsets.bottom)
            let topControlPadding = effectiveTopSafeArea + MHBTheme.Spacing.s1
            let bottomControlPadding = max(
                MHBTheme.Spacing.s8,
                effectiveBottomSafeArea + MHBTheme.Spacing.s3
            )

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: viewportSize.width, height: viewportSize.height)
                    .clipped()
                    .scaleEffect(imageScale * tempScale)
                    .offset(
                        x: imageOffset.width + tempOffset.width,
                        y: imageOffset.height + tempOffset.height
                    )
                    .gesture(dragGesture)
                    .simultaneousGesture(magnificationGesture)

                MHBRectCropMaskOverlay(
                    cropFrameSize: cropFrameSize,
                    isInteracting: isInteracting
                )
                .frame(width: viewportSize.width, height: viewportSize.height)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.2), value: isInteracting)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                        .padding(.top, topControlPadding)

                    Spacer()

                    bottomBar(
                        viewportSize: viewportSize,
                        cropFrameSize: cropFrameSize
                    )
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.bottom, bottomControlPadding)
                }
            }
            .ignoresSafeArea()
            .background {
                MHBWindowSafeAreaReader { insets in
                    guard !windowSafeAreaInsets.mhb_isApproximatelyEqual(to: insets) else {
                        return
                    }
                    windowSafeAreaInsets = insets
                }
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("取消")

            Spacer()

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isInteracting = true
                tempOffset = value.translation
            }
            .onEnded { value in
                imageOffset.width += value.translation.width
                imageOffset.height += value.translation.height
                tempOffset = .zero
                isInteracting = false
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isInteracting = true
                tempScale = value
            }
            .onEnded { value in
                imageScale = min(max(imageScale * value, 1), 5)
                tempScale = 1
                isInteracting = false
            }
    }

    private func bottomBar(
        viewportSize: CGSize,
        cropFrameSize: CGSize
    ) -> some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button("取消", action: onCancel)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)
                .frame(height: 48)
                .padding(.horizontal, MHBTheme.Spacing.s4)

            Spacer()

            Button("完成") {
                guard let croppedImage = cropImage(
                    viewportSize: viewportSize,
                    cropFrameSize: cropFrameSize
                ) else {
                    return
                }
                onSave(croppedImage)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 48)
            .padding(.horizontal, MHBTheme.Spacing.s6)
            .background(MHBTheme.ColorToken.primary.color, in: .rect(cornerRadius: MHBTheme.Radius.large))
        }
    }

    private func cropSize(for viewportSize: CGSize) -> CGSize {
        let cropWidth = max(viewportSize.width, 1)
        return CGSize(
            width: cropWidth,
            height: cropWidth / cropAspectRatio
        )
    }

    private func cropImage(
        viewportSize: CGSize,
        cropFrameSize: CGSize
    ) -> UIImage? {
        guard let cgImage = originalImage.cgImage else {
            return nil
        }

        let imagePixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let cropRect = MHBRectImageCropGeometryCalculator.cropRect(
            imagePixelSize: imagePixelSize,
            viewportSize: viewportSize,
            imageScale: imageScale,
            imageOffset: imageOffset,
            cropFrameSize: cropFrameSize
        ).integral

        let imageBounds = CGRect(origin: .zero, size: imagePixelSize)
        guard imageBounds.contains(cropRect),
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(
            cgImage: croppedCGImage,
            scale: originalImage.scale,
            orientation: .up
        )
    }
}

// MHBRectCropMaskOverlay 矩形裁剪遮罩
// 核心职责：
// - 展示矩形裁剪框和框外弱化遮罩
// - 在用户拖拽缩放时保持裁剪焦点清晰
private struct MHBRectCropMaskOverlay: View {
    let cropFrameSize: CGSize
    let isInteracting: Bool

    var body: some View {
        ZStack {
            MHBCropOutsideBlurLayer(
                holeShape: MHBRectCropHoleShape(
                    cropFrameSize: cropFrameSize
                ),
                isInteracting: isInteracting
            )

            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(.white, lineWidth: 2)
                .frame(width: cropFrameSize.width, height: cropFrameSize.height)
        }
    }
}

// MHBRectCropHoleShape 矩形裁剪镂空形状
// 核心职责：
// - 在矩形遮罩中挖出居中的圆角矩形裁剪区域
// - 为背景图裁剪遮罩提供可复用 Shape
private struct MHBRectCropHoleShape: Shape {
    let cropFrameSize: CGSize

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)

        let cropRect = CGRect(
            x: rect.midX - cropFrameSize.width / 2,
            y: rect.midY - cropFrameSize.height / 2,
            width: cropFrameSize.width,
            height: cropFrameSize.height
        )
        path.addPath(Path(roundedRect: cropRect, cornerRadius: MHBTheme.Radius.large))

        return path
    }
}

private extension UIImage {
    func mhb_normalizedForRectCropping() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
