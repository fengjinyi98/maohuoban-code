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

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            PetAlbumPhotoStackCover(imageAssetName: coverImageAssetName)

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
// - 绘制封面下方的多层照片纸
// - 保持封面图片与内描边视觉一致
private struct PetAlbumPhotoStackCover: View {
    let imageAssetName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .rotationEffect(.degrees(5))
                .scaleEffect(0.92)
                .offset(y: MHBTheme.Spacing.s1)

            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .fill(MHBTheme.ColorToken.background.color)
                .rotationEffect(.degrees(-4))
                .scaleEffect(0.96)

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
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.08), radius: 10, y: 6)
    }
}
