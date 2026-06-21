import SwiftUI
import MaohuobanDesignSystem

// FeedAuthorRow Feed 作者信息行
// 核心职责：
// - 统一展示头像、作者名称、发布时间与身份标签
// - 为顶部更多按钮预留稳定命中空间
struct FeedAuthorRow: View {
    let title: String
    let subtitle: String
    let avatarAssetName: String
    let badge: FeedAuthorBadge?
    let reservesTrailingButtonSpace: Bool

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: FeedCardMetrics.avatarSize, height: FeedCardMetrics.avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1 / 2) {
                HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if let badge {
                        FeedAuthorBadgeView(badge: badge)
                    }
                }

                Text(subtitle)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: MHBTheme.Spacing.s2)

            if reservesTrailingButtonSpace {
                Color.clear
                    .frame(
                        width: FeedCardMetrics.moreButtonHitSize,
                        height: FeedCardMetrics.moreButtonHitSize
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}

// FeedAuthorBadgeView Feed 作者标签视图
// 核心职责：
// - 将身份标签模型渲染为紧凑胶囊标签
// - 保持推荐解释与业务身份标签的视觉一致性
private struct FeedAuthorBadgeView: View {
    let badge: FeedAuthorBadge

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            if let systemImageName = badge.systemImageName {
                Image(systemName: systemImageName)
                    .imageScale(.small)
            }

            Text(badge.title)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(badge.style.foregroundColor)
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s1 / 2)
        .background {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous)
                .fill(badge.style.backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous)
                .strokeBorder(badge.style.borderColor, lineWidth: 1)
        }
    }
}
