import SwiftUI
import MaohuobanDesignSystem

// PetAlbumDetailHeader 相册详情头部
// 核心职责：
// - 展示当前相册标题和照片数量
// - 承载添加照片的主操作入口
struct PetAlbumDetailHeader: View {
    let title: String
    let subtitle: String
    let onAddPhotos: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: MHBTheme.Spacing.s4) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(title)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(2)

                Text(subtitle)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s3)

            Button(action: onAddPhotos) {
                Label("添加照片", systemImage: "plus")
                    .font(MHBTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .background(MHBTheme.ColorToken.labelPrimary.color)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("petAlbum.detail.addPhotos")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("petAlbum.detail.header")
    }
}
