import SwiftUI
import MaohuobanDesignSystem

// ProfileBadgesSection 我的页勋章展示区块
// 核心职责：
// - 展示“我的勋章”卡片头部（带右箭头入口）
// - 承载水平排列的已获得勋章，采用同心圆圈层设计的精致徽章样式
struct ProfileBadgesSection: View {
    let badges: [ProfileBadge]
    let onHeaderClick: () -> Void
    let onBadgeClick: (ProfileBadge) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // Header Row
            Button(action: onHeaderClick) {
                HStack {
                    Text("我的勋章")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
            }
            .buttonStyle(.plain)

            // Horizontal Badges Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MHBTheme.Spacing.s4) {
                    ForEach(badges) { badge in
                        ProfileBadgeItemView(badge: badge) {
                            onBadgeClick(badge)
                        }
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.badgesSection")
    }
}

// ProfileBadgeItemView 勋章卡片中的单个徽章视图
// 核心职责：
// - 渲染单个徽章的同心圆勋章轮廓、标题和获得描述
private struct ProfileBadgeItemView: View {
    let badge: ProfileBadge
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: MHBTheme.Spacing.s1) {
                ProfileBadgeArtwork(
                    imageAssetName: badge.imageAssetName,
                    isEarned: badge.isEarned,
                    size: 56,
                    shadowRadius: 5
                )
                .frame(width: 56, height: 56)

                Text(badge.title)
                    .font(MHBTheme.Typography.caption.bold())
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .frame(width: 72)
                    .multilineTextAlignment(.center)

                ProfileBadgeStatusPill(badge: badge)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(badge.title)，\(badge.progressText)")
    }
}
