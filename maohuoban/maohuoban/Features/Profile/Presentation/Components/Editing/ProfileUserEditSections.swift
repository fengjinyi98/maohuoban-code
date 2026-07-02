import SwiftUI
import MaohuobanDesignSystem
import UIKit

// ProfileUserEditAvatarHeader 用户资料编辑头像头部
// 核心职责：
// - 对齐首页编辑档案页顶部头像编辑入口
// - 展示当前用户身份和头像编辑提示
struct ProfileUserEditAvatarHeader: View {
    let displayName: String
    let avatarAssetName: String
    let avatarURLString: String?
    let localAvatarImage: UIImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                ZStack(alignment: .bottomTrailing) {
                    avatarImage
                        .frame(width: 78, height: 78)
                        .background(MHBTheme.ColorToken.cardSolid.color)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                        }

                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.78))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
                        }
                        .offset(x: 1, y: 1)
                }

                Text(displayName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, MHBTheme.Spacing.s3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑头像")
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let localAvatarImage {
            Image(uiImage: localAvatarImage)
                .resizable()
                .scaledToFill()
        } else if let avatarURLString,
                  let url = MHBBackendEndpoint.resolve(avatarURLString) {
            MHBRemoteImage(url: url, contentMode: .fill) {
                fallbackAvatarImage
            }
        } else {
            fallbackAvatarImage
        }
    }

    private var fallbackAvatarImage: some View {
        Image(avatarAssetName)
            .resizable()
            .scaledToFill()
    }
}

// ProfileUserEditCoverValue 用户资料背景行值
// 核心职责：
// - 在资料编辑行右侧展示主页背景缩略图
// - 使用编辑档案页背景缩略图相同的比例和圆角
struct ProfileUserEditCoverValue: View {
    let assetName: String
    let coverURLString: String?
    let localCoverImage: UIImage?

    var body: some View {
        Group {
            if let localCoverImage {
                Image(uiImage: localCoverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                remoteOrAssetCover
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private var remoteOrAssetCover: some View {
        if let coverURLString,
           let url = MHBBackendEndpoint.resolve(coverURLString) {
            MHBRemoteImage(url: url, contentMode: .fill) {
                emptyCover
            }
        } else if assetName.isEmpty == false {
            assetCover
        } else {
            emptyCover
        }
    }

    private var assetCover: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
    }

    // emptyCover 背景缩略图空态
    // 核心职责：
    // - 在无远端封面和本地资源时提供视觉占位
    // - 对齐封面 .empty 空态的回退行为
    private var emptyCover: some View {
        MHBTheme.ColorToken.cardSolid.color
    }
}
