import SwiftUI
import MaohuobanDesignSystem

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
            MHBLocalLivePhotoView(
                stillURL: livePhoto.stillURL,
                pairedVideoURL: livePhoto.pairedVideoURL,
                cropMetadata: livePhoto.cropMetadata
            ) {
                if let previewImage = livePhoto.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    fallbackColor
                }
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
        case .remoteLivePhoto(let stillURLString, let pairedVideoURLString, let cropMetadata, let fallbackImageAssetName):
            if let stillURL = MHBBackendEndpoint.resolve(stillURLString),
               let pairedVideoURL = MHBBackendEndpoint.resolve(pairedVideoURLString) {
                MHBRemoteLivePhotoView(
                    stillURL: stillURL,
                    pairedVideoURL: pairedVideoURL,
                    cropMetadata: cropMetadata
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

enum PetProfileBackgroundUploadState {
    case idle
    case uploading
    case saved
}
