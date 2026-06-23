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
    let onSaveResult: (MHBRectImageCropResult) -> Void

    @State var imageOffset: CGSize = .zero
    @State var imageScale: CGFloat = 1
    @State var tempOffset: CGSize = .zero
    @State var tempScale: CGFloat = 1
    @State var isInteracting = false
    @State var isDismissing = false
    @State var windowSafeAreaInsets: UIEdgeInsets = .zero

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
        self.onSaveResult = { result in
            onSave(result.image)
        }
    }

    init(
        originalImage: UIImage,
        title: String = "裁剪背景",
        cropAspectRatio: CGFloat,
        onCancel: @escaping () -> Void,
        onSaveResult: @escaping (MHBRectImageCropResult) -> Void
    ) {
        self.originalImage = originalImage.mhb_normalizedForRectCropping()
        self.title = title
        self.cropAspectRatio = max(cropAspectRatio, 0.1)
        self.onCancel = onCancel
        self.onSaveResult = onSaveResult
    }

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let cropFrameSize = cropSize(for: viewportSize)
            let imageDisplaySize = MHBImageCropDisplayGeometryCalculator.initialDisplaySize(
                imagePointSize: originalImage.size,
                viewportSize: viewportSize
            )
            let effectiveTopSafeArea = max(geometry.safeAreaInsets.top, windowSafeAreaInsets.top)
            let effectiveBottomSafeArea = max(geometry.safeAreaInsets.bottom, windowSafeAreaInsets.bottom)
            let topControlPadding = effectiveTopSafeArea + MHBTheme.Spacing.s1
            let bottomControlPadding = max(
                MHBTheme.Spacing.s8,
                effectiveBottomSafeArea + MHBTheme.Spacing.s3
            )

            ZStack {
                Color.black.ignoresSafeArea()

                ZStack {
                    Image(uiImage: originalImage)
                        .resizable()
                        .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
                        .scaleEffect(imageScale * tempScale)
                        .offset(
                            x: imageOffset.width + tempOffset.width,
                            y: imageOffset.height + tempOffset.height
                        )
                }
                .frame(width: viewportSize.width, height: viewportSize.height)
                .contentShape(Rectangle())
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
                        imageDisplaySize: imageDisplaySize,
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
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
    }

    private var topBar: some View {
        HStack {
            Button(action: {
                handleCancel(source: "top")
            }) {
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
        imageDisplaySize: CGSize,
        cropFrameSize: CGSize
    ) -> some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button("取消") {
                handleCancel(source: "bottom")
            }
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)
                .frame(height: 48)
                .padding(.horizontal, MHBTheme.Spacing.s4)

            Spacer()

            Button("完成") {
                guard let result = cropResult(
                    viewportSize: viewportSize,
                    imageDisplaySize: imageDisplaySize,
                    cropFrameSize: cropFrameSize
                ) else {
                    return
                }
                onSaveResult(result)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 48)
            .padding(.horizontal, MHBTheme.Spacing.s6)
            .background(MHBTheme.ColorToken.primary.color, in: .rect(cornerRadius: MHBTheme.Radius.large))
        }
    }

}
