import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileBackgroundPreviewScreen 宠物背景预览页
// 核心职责：
// - 提供当前宠物背景图片或视频的沉浸式预览
// - 承接图片选择裁剪、视频选择和临时上传状态流转
struct PetProfileBackgroundPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let petName: String
    let heroMedia: PetProfileEditProfile.HeroMedia
    let localHeroMedia: PetProfileHeroMediaDraft?
    let onHeroMediaUpdated: (PetProfileHeroMediaDraft) async -> Bool

    @State private var previewMedia: PetProfileHeroMediaDraft?
    @State private var isImagePickerPresented = false
    @State private var isVideoPickerPresented = false
    @State private var cropTarget: MHBIdentifiableUIImage?
    @State private var uploadState = PetProfileBackgroundUploadState.idle

    private let previewAspectRatio = CGFloat(393.0 / 440.0)

    init(
        petName: String,
        heroMedia: PetProfileEditProfile.HeroMedia,
        localHeroMedia: PetProfileHeroMediaDraft?,
        onHeroMediaUpdated: @escaping (PetProfileHeroMediaDraft) async -> Bool
    ) {
        self.petName = petName
        self.heroMedia = heroMedia
        self.localHeroMedia = localHeroMedia
        self.onHeroMediaUpdated = onHeroMediaUpdated
        _previewMedia = State(initialValue: localHeroMedia)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s3)

                Spacer(minLength: MHBTheme.Spacing.s6)

                mediaPreview
                    .padding(.horizontal, MHBTheme.Spacing.s4)

                uploadStatus
                    .padding(.top, MHBTheme.Spacing.s4)

                Spacer(minLength: MHBTheme.Spacing.s6)

                actionButtons
                    .padding(.horizontal, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isImagePickerPresented) {
            MHBSystemMediaPicker(
                request: .singleImage,
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
        .sheet(isPresented: $isVideoPickerPresented) {
            MHBSystemMediaPicker(
                request: .singleVideoOrLivePhoto,
                onComplete: { result in
                    isVideoPickerPresented = false
                    handleVideoPickerResult(result)
                },
                onCancel: {
                    isVideoPickerPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $cropTarget) { target in
            MHBRectImageCropScreen(
                originalImage: target.image,
                title: "裁剪宠物背景",
                cropAspectRatio: previewAspectRatio,
                onCancel: {
                    cropTarget = nil
                },
                onSave: handleCroppedBackgroundImage
            )
        }
        .accessibilityIdentifier("pet.profileBackgroundPreview.screen")
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

            Text("\(petName)的背景")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    private var mediaPreview: some View {
        PetProfileHeroMediaPreviewContent(
            heroMedia: heroMedia,
            localHeroMedia: previewMedia,
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
    private var uploadStatus: some View {
        switch uploadState {
        case .idle:
            Text("当前宠物背景")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.66))
        case .uploading:
            HStack(spacing: MHBTheme.Spacing.s2) {
                ProgressView()
                    .tint(.white)

                Text("正在保存背景...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.76))
            }
        case .saved:
            Text("背景已上传")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.76))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            mediaActionButton(
                title: "选择背景图片",
                systemImage: "photo",
                action: {
                    isImagePickerPresented = true
                }
            )

            mediaActionButton(
                title: "选择背景视频",
                systemImage: "video",
                action: {
                    isVideoPickerPresented = true
                }
            )
        }
    }

    private func mediaActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: systemImage)
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
        guard let image = result.images.first else {
            return
        }

        cropTarget = MHBIdentifiableUIImage(image: image)
    }

    private func handleVideoPickerResult(_ result: MHBMediaPickerResult) {
        if let livePhoto = result.livePhotos.first {
            saveHeroMedia(.livePhoto(livePhoto))
            return
        }

        guard let video = result.videos.first else {
            return
        }
        saveHeroMedia(.video(video.url))
    }

    private func handleCroppedBackgroundImage(_ image: UIImage) {
        cropTarget = nil
        saveHeroMedia(.image(image))
    }

    private func saveHeroMedia(_ media: PetProfileHeroMediaDraft) {
        previewMedia = media
        uploadState = .uploading

        Task { @MainActor in
            let didSave = await onHeroMediaUpdated(media)
            uploadState = didSave ? .saved : .idle
        }
    }
}

// PetProfileHeroMediaPreviewContent 宠物背景预览内容
// 核心职责：
// - 统一渲染本地草稿背景和已有档案背景
// - 支持图片、bundle 视频和相册临时视频 URL
struct PetProfileHeroMediaPreviewContent: View {
    let heroMedia: PetProfileEditProfile.HeroMedia
    let localHeroMedia: PetProfileHeroMediaDraft?
    let fallbackColor: Color

    var body: some View {
        ZStack {
            fallbackColor

            if let localHeroMedia {
                localMediaContent(localHeroMedia)
            } else {
                profileMediaContent
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func localMediaContent(_ media: PetProfileHeroMediaDraft) -> some View {
        switch media {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        case .video(let url):
            MHBMutedLoopingVideoView(url: url)
        case .livePhoto(let livePhoto):
            if let previewImage = livePhoto.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackColor
            }
        }
    }

    @ViewBuilder
    private var profileMediaContent: some View {
        switch heroMedia {
        case .image(let assetName):
            if assetName.isEmpty {
                fallbackColor
            } else {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            }
        case .remoteImage(let urlString, let fallbackAssetName):
            if let url = MHBBackendEndpoint.resolve(urlString) {
                MHBRemoteImage(url: url, contentMode: .fill) {
                    fallbackImage(fallbackAssetName)
                }
            } else {
                fallbackImage(fallbackAssetName)
            }
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            if MHBLocalMediaResource.url(resourceName: resourceName, fileExtension: fileExtension) != nil {
                MHBMutedLoopingVideoView(
                    resourceName: resourceName,
                    fileExtension: fileExtension
                )
            } else if let fallbackImageAssetName {
                Image(fallbackImageAssetName)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackColor
            }
        case .remoteVideo(let urlString, let fallbackImageURLString, let fallbackImageAssetName):
            if let url = MHBBackendEndpoint.resolve(urlString) {
                MHBMutedLoopingVideoView(url: url)
            } else if let fallbackImageURLString,
                      let fallbackURL = MHBBackendEndpoint.resolve(fallbackImageURLString) {
                MHBRemoteImage(url: fallbackURL, contentMode: .fill) {
                    fallbackImage(fallbackImageAssetName)
                }
            } else {
                fallbackImage(fallbackImageAssetName)
            }
        case .remoteLivePhoto(let stillURLString, let pairedVideoURLString, let fallbackImageAssetName):
            if let stillURL = MHBBackendEndpoint.resolve(stillURLString),
               let pairedVideoURL = MHBBackendEndpoint.resolve(pairedVideoURLString) {
                MHBRemoteLivePhotoView(
                    stillURL: stillURL,
                    pairedVideoURL: pairedVideoURL
                ) {
                    fallbackImage(fallbackImageAssetName)
                }
            } else {
                fallbackImage(fallbackImageAssetName)
            }
        }
    }

    @ViewBuilder
    private func fallbackImage(_ assetName: String?) -> some View {
        if let assetName, assetName.isEmpty == false {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            fallbackColor
        }
    }
}

private enum PetProfileBackgroundUploadState {
    case idle
    case uploading
    case saved
}
