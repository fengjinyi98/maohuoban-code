import SwiftUI
import MaohuobanDesignSystem

// PetAlbumPhotoStackCard 相册叠放封面卡片
// 核心职责：
// - 呈现设计稿中的照片纸叠放效果
// - 展示相册名称、数量和更新时间
struct PetAlbumPhotoStackCard: View {
    let title: String
    let photoCountText: String
    let updatedText: String
    let coverImageAssetName: String
    let isPrivate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            PetAlbumPhotoStackCover(
                imageAssetName: coverImageAssetName,
                isPrivate: isPrivate
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MHBTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Text("\(photoCountText) · \(updatedText)")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(photoCountText)，\(updatedText)")
    }
}

// PetAlbumPhotoStackCover 相册叠放封面
// 核心职责：
// - 绘制设计稿中的多层照片纸叠放效果
// - 保持封面图片与内描边视觉一致
private struct PetAlbumPhotoStackCover: View {
    let imageAssetName: String
    let isPrivate: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .top) {
                // 底部第三层纸张
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .fill(MHBTheme.ColorToken.labelQuaternary.color.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
                    .frame(height: MHBTheme.Spacing.s5)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .offset(y: -MHBTheme.Spacing.s3)

                // 底部第二层纸张
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .fill(MHBTheme.ColorToken.labelQuaternary.color)
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
                    .frame(height: MHBTheme.Spacing.s5)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .offset(y: -MHBTheme.Spacing.s3 / 2)

                // 主相册封面图片
                PetAlbumAssetImage(imageAssetName: imageAssetName)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.labelPrimary.color.opacity(0.12), lineWidth: 3)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
            }

            if isPrivate {
                Image(systemName: "lock.fill")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .frame(width: MHBTheme.Spacing.s6, height: MHBTheme.Spacing.s6)
                    .background(MHBTheme.ColorToken.labelPrimary.color.opacity(0.42), in: Circle())
                    .padding(MHBTheme.Spacing.s3)
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.top, MHBTheme.Spacing.s3)
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.06), radius: 10, y: 6)
    }
}
