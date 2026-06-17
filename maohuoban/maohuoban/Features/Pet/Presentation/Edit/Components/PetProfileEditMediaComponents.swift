import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileEditValueText 编辑资料行文本值
// 核心职责：
// - 统一资料行右侧文本样式
// - 处理长文本截断，避免挤压右侧箭头
struct PetProfileEditValueText: View {
    let value: String

    var body: some View {
        let isPlaceholder = value.isEmpty || value.hasPrefix("选择") || value == "暂未设置" || value == "暂无" || value == "未添加"
        Text(value)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(isPlaceholder ? MHBTheme.ColorToken.labelTertiary.color : MHBTheme.ColorToken.labelPrimary.color)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// PetProfileEditAvatarImage 宠物头像图片
// 核心职责：
// - 优先展示远端头像
// - 在头像缺失时按物种提供稳定兜底
struct PetProfileEditAvatarImage: View {
    let avatarURL: String?
    let localAvatarImage: UIImage?
    let species: PetProfileEditProfile.Species
    let size: CGFloat

    var body: some View {
        if let localAvatarImage {
            Image(uiImage: localAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let avatarURL, let url = MHBBackendEndpoint.resolve(avatarURL) {
            MHBRemoteImage(url: url, contentMode: .fill) {
                fallbackAvatar
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        Image(systemName: species.systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .frame(width: size, height: size)
            .background(MHBTheme.ColorToken.primaryBackground.color)
            .clipShape(Circle())
    }
}

// PetProfileEditMediaThumbnail 背景媒体缩略图
// 核心职责：
// - 展示当前宠物背景媒体的缩略预览
// - 兼容图片和本地视频 mock 资源
struct PetProfileEditMediaThumbnail: View {
    let media: PetProfileEditProfile.HeroMedia
    let localMedia: PetProfileHeroMediaDraft?
    let uploadState: PetMediaUploadSlotState

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mediaContent

            PetMediaUploadProgressOverlay(state: uploadState)

            if isVideo {
                Image(systemName: "play.fill")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 12, height: 12)
                    .background(Color.black.opacity(0.58))
                    .clipShape(Circle())
                    .padding(2)
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var isVideo: Bool {
        if let localMedia,
           case .video = localMedia {
            return true
        }

        if localMedia == nil,
           case .video = media {
            return true
        }

        if localMedia == nil,
           case .remoteVideo = media {
            return true
        }

        return false
    }

    @ViewBuilder
    private var mediaContent: some View {
        if let localMedia {
            switch localMedia {
            case .image(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            case .video(let url):
                MHBMutedLoopingVideoView(url: url)
            }
        } else {
            switch media {
            case .image(let assetName):
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            case .remoteImage(let urlString, let fallbackAssetName):
                if let url = MHBBackendEndpoint.resolve(urlString) {
                    MHBRemoteImage(url: url, contentMode: .fill) {
                        Image(fallbackAssetName)
                            .resizable()
                            .scaledToFill()
                    }
                } else {
                    Image(fallbackAssetName)
                        .resizable()
                        .scaledToFill()
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
                    MHBTheme.ColorToken.primaryBackground.color
                }
            case .remoteVideo(let urlString, let fallbackImageURLString, let fallbackImageAssetName):
                if let url = MHBBackendEndpoint.resolve(urlString) {
                    MHBMutedLoopingVideoView(url: url)
                } else if let fallbackImageURLString,
                          let fallbackURL = MHBBackendEndpoint.resolve(fallbackImageURLString) {
                    MHBRemoteImage(url: fallbackURL, contentMode: .fill) {
                        fallbackRemoteVideoImage(fallbackImageAssetName)
                    }
                } else {
                    fallbackRemoteVideoImage(fallbackImageAssetName)
                }
            }
        }
    }

    @ViewBuilder
    private func fallbackRemoteVideoImage(_ assetName: String?) -> some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            MHBTheme.ColorToken.primaryBackground.color
        }
    }
}

// PetProfileEditTagFlow 性格标签展示
// 核心职责：
// - 在资料行内展示宠物性格标签
// - 支持标签数量变化时自动换行
struct PetProfileEditTagFlow: View {
    let tags: [String]

    var body: some View {
        if tags.isEmpty {
            PetProfileEditValueText(value: "暂未设置")
        } else {
            HStack(spacing: MHBTheme.Spacing.s1) {
                ForEach(tags.prefix(3), id: \.self) { tag in
                    MHBTagView(tag, style: .neutral, size: .small)
                }
            }
        }
    }
}
