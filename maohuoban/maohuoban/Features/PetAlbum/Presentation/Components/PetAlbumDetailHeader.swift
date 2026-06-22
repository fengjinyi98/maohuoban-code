import SwiftUI
import MaohuobanDesignSystem

// PetAlbumDetailHeader 相册详情头部
// 核心职责：
// - 展示当前相册标题和照片数量
// - 为照片墙内容提供页面级信息起点
struct PetAlbumDetailHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(title)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(2)

            Text(subtitle)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("petAlbum.detail.header")
    }
}
