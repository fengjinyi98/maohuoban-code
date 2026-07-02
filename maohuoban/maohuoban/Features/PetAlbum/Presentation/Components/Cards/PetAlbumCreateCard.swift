import SwiftUI
import MaohuobanDesignSystem

// PetAlbumCreateCard 新建相册入口卡片
// 核心职责：
// - 在相册网格中承载新建入口
// - 使用虚线封面保持与设计稿一致的网格占位
struct PetAlbumCreateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "plus")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))

                Text("新建相册")
                    .font(MHBTheme.Typography.footnote.weight(.semibold))
            }
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(MHBTheme.ColorToken.background.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                    .stroke(
                        MHBTheme.ColorToken.labelQuaternary.color,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                    )
            }
            .padding(.top, MHBTheme.Spacing.s3) // 与其他卡片顶部的层叠间距对齐

            VStack(alignment: .leading, spacing: 2) {
                Text("新建相册")
                    .font(MHBTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("整理照片")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel("新建相册")
    }
}
