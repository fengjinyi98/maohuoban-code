import SwiftUI
import MaohuobanDesignSystem

// SameCityCommodityPublisherSection 商品发布者区
// 核心职责：
// - 展示救助人、繁育人或商家认证信息
// - 为沉浸式头部身份显隐提供滚动位置观测
struct SameCityCommodityPublisherSection: View {
    let publisher: SameCityCommodityDetailPublisher
    let onOffsetChange: (CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            SameCityCommoditySectionHeading(title: "发布者")

            HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                MHBAvatar(
                    subject: .user(
                        MHBAvatarUser(
                            id: publisher.name,
                            displayName: publisher.name,
                            source: .asset(publisher.avatarAssetName),
                            sex: .unknown,
                            sexVisibility: .hidden
                        )
                    ),
                    size: .custom(44),
                    shape: .circle
                )

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                        Text(publisher.name)
                            .font(MHBTheme.Typography.callout.weight(.bold))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .lineLimit(1)

                        MHBTagView(
                            publisher.badgeTitle,
                            systemImage: "checkmark.seal.fill",
                            style: .primary,
                            size: .small
                        )
                        .lineLimit(1)
                    }

                    Text(publisher.subtitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(2)
                }
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(.vertical, MHBTheme.Spacing.s2)
            .contentShape(.rect)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .scrollView).minY
        } action: { minY in
            onOffsetChange(minY)
        }
    }
}
