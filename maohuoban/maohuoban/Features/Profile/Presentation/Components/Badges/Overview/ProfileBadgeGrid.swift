import SwiftUI
import MaohuobanDesignSystem

// ProfileBadgeGrid 全部勋章三列网格
// 核心职责：
// - 按设计稿展示 16 枚 V1 冷启动勋章
// - 将勋章点击事件转发给页面层打开详情弹层
struct ProfileBadgeGrid: View {
    let badges: [ProfileBadge]
    let onSelectBadge: (ProfileBadge) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s2),
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s2),
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: MHBTheme.Spacing.s6) {
            ForEach(badges) { badge in
                ProfileBadgeGridItem(
                    badge: badge,
                    onSelect: {
                        onSelectBadge(badge)
                    }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.badges.grid")
    }
}

// ProfileBadgeGridItem 单个勋章网格项
// 核心职责：
// - 展示勋章图片、名称与点亮状态
// - 提供稳定点击热区进入勋章详情
private struct ProfileBadgeGridItem: View {
    let badge: ProfileBadge
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
                ProfileBadgeArtwork(
                    imageAssetName: badge.imageAssetName,
                    isEarned: badge.isEarned,
                    size: 94,
                    shadowRadius: 10
                )
                .frame(width: 102, height: 102)

                Text(badge.title)
                    .font(MHBTheme.Typography.footnote.weight(.bold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                ProfileBadgeStatusPill(badge: badge)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(badge.title)，\(badge.progressText)")
        .accessibilityIdentifier("profile.badges.grid.item.\(badge.id)")
    }

    private var titleColor: Color {
        badge.isEarned ? MHBTheme.ColorToken.labelPrimary.color : MHBTheme.ColorToken.labelSecondary.color
    }
}
