import SwiftUI
import MaohuobanDesignSystem

// PetPantryArchivedRestoreSection 已归档食品恢复区
// 核心职责：
// - 展示当前分类下可恢复的已归档食品资产
// - 将恢复动作交给上层 Store 命令处理
struct PetPantryArchivedRestoreSection: View {
    let items: [PantryItem]
    let restoreTitle: String
    let onRestore: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("已归档")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            ForEach(items) { item in
                HStack(spacing: MHBTheme.Spacing.s3) {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                        Text(item.name)
                            .font(MHBTheme.Typography.callout.weight(.semibold))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .lineLimit(1)

                        Text("\(item.brand) · \(item.statusLabel)")
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .lineLimit(1)
                    }

                    Spacer(minLength: MHBTheme.Spacing.s2)

                    Button(restoreTitle) {
                        onRestore(item.id)
                    }
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                    .clipShape(Capsule())
                }
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            }
        }
    }
}
