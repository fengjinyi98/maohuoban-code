import SwiftUI
import MaohuobanDesignSystem
import UIKit

// ProfileUserBackgroundPreviewScreen 用户主页背景预览页
// 核心职责：
// - 提供个人主页背景图片的沉浸式预览
// - 复用照片选择和矩形裁剪基础设施完成前端本地更新
struct ProfileUserBackgroundPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let displayName: String
    let coverAssetName: String
    let coverURLString: String?
    let localCoverImage: UIImage?
    let onCoverUpdated: (UIImage) async -> Bool

    @State private var previewImage: UIImage?
    @State private var isImagePickerPresented = false
    @State private var cropTarget: MHBIdentifiableUIImage?
    @State private var saveState = ProfileUserBackgroundSaveState.idle

    private let previewAspectRatio = CGFloat(393.0) / ProfileUserHomeLayout.coverHeight

    init(
        displayName: String,
        coverAssetName: String,
        coverURLString: String?,
        localCoverImage: UIImage?,
        onCoverUpdated: @escaping (UIImage) async -> Bool
    ) {
        self.displayName = displayName
        self.coverAssetName = coverAssetName
        self.coverURLString = coverURLString
        self.localCoverImage = localCoverImage
        self.onCoverUpdated = onCoverUpdated
        _previewImage = State(initialValue: localCoverImage)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s3)

                Spacer(minLength: MHBTheme.Spacing.s6)

                backgroundPreview
                    .padding(.horizontal, MHBTheme.Spacing.s4)

                saveStatus
                    .padding(.top, MHBTheme.Spacing.s4)

                Spacer(minLength: MHBTheme.Spacing.s6)

                selectBackgroundButton
                    .padding(.horizontal, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isImagePickerPresented) {
            MHBPhotoLibraryPickerScreen(
                title: "选择主页背景",
                onComplete: { result in
                    isImagePickerPresented = false
                    handleImagePickerResult(result)
                },
                onCancel: {
                    isImagePickerPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $cropTarget) { target in
            MHBRectImageCropScreen(
                originalImage: target.image,
                title: "裁剪主页背景",
                cropAspectRatio: previewAspectRatio,
                onCancel: {
                    cropTarget = nil
                },
                onSave: handleCroppedBackground
            )
        }
        .accessibilityIdentifier("profile.userBackgroundPreview.screen")
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("关闭")

            Spacer()

            Text("\(displayName)的主页背景")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    private var backgroundPreview: some View {
        ProfileUserBackgroundPreviewContent(
            assetName: coverAssetName,
            coverURLString: coverURLString,
            localImage: previewImage,
            fallbackColor: Color.white.opacity(0.1)
        )
        .aspectRatio(previewAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var saveStatus: some View {
        switch saveState {
        case .idle:
            Text("当前主页背景")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.66))
        case .saving:
            HStack(spacing: MHBTheme.Spacing.s2) {
                ProgressView()
                    .tint(.white)

                Text("正在保存背景...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.76))
            }
        case .saved:
            Text("背景已保存")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.76))
        }
    }

    private var selectBackgroundButton: some View {
        Button {
            isImagePickerPresented = true
        } label: {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text("选择背景图片")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white.opacity(0.14), in: .rect(cornerRadius: MHBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func handleImagePickerResult(_ result: MHBMediaPickerResult) {
        if let livePhoto = result.livePhotos.first,
           let previewImage = livePhoto.previewImage {
            cropTarget = MHBIdentifiableUIImage(image: previewImage)
            return
        }

        guard let image = result.images.first else {
            return
        }

        cropTarget = MHBIdentifiableUIImage(image: image)
    }

    private func handleCroppedBackground(_ image: UIImage) {
        cropTarget = nil
        saveState = .saving

        Task { @MainActor in
            let didSave = await onCoverUpdated(image)
            if didSave {
                previewImage = image
            }
            saveState = didSave ? .saved : .idle
        }
    }
}

// ProfileUserBackgroundPreviewContent 用户主页背景预览内容
// 核心职责：
// - 渲染本地裁剪图片或默认资源背景
// - 保持预览内容始终填满裁剪比例容器
private struct ProfileUserBackgroundPreviewContent: View {
    let assetName: String
    let coverURLString: String?
    let localImage: UIImage?
    let fallbackColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                fallbackColor

                if let localImage {
                    imageContent(Image(uiImage: localImage), size: proxy.size)
                } else if let coverURLString,
                          let url = MHBBackendEndpoint.resolve(coverURLString) {
                    MHBRemoteImage(url: url, contentMode: .fill) {
                        imageContent(Image(assetName), size: proxy.size)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                } else if assetName.isEmpty == false {
                    imageContent(Image(assetName), size: proxy.size)
                }
            }
        }
        .clipped()
    }

    private func imageContent(
        _ image: Image,
        size: CGSize
    ) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

private enum ProfileUserBackgroundSaveState {
    case idle
    case saving
    case saved
}
