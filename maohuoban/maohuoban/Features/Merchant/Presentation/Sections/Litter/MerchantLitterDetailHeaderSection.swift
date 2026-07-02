import SwiftUI
import MaohuobanDesignSystem

// MerchantLitterDetailHeaderSection 商家窝次摘要模块
// 核心职责：
// - 展示窝次名称、出生日期和状态
// - 呈现出生、成活、可售数量
struct MerchantLitterDetailHeaderSection: View {
    let detail: MerchantLitterDetail

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text(detail.name)
                        .font(MHBTheme.Typography.title)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    Text("\(String(localized: detail.species.displayTitle)) · \(detail.bornAt) 出生")
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    Text(detail.status.displayTitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s2)
                        .padding(.vertical, MHBTheme.Spacing.s1)
                        .background(MHBTheme.ColorToken.primaryBackground.color)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: MHBTheme.Spacing.s3) {
                MerchantLitterCountCell(title: "出生", value: "\(detail.bornCount)")
                MerchantLitterCountCell(title: "成活", value: "\(detail.aliveCount)")
                MerchantLitterCountCell(title: "可售", value: "\(detail.availableCount)")
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
        )
        .accessibilityIdentifier("merchant.litterDetail.header")
    }
}

// MerchantLitterCountCell 窝次数量单元
// 核心职责：
// - 展示窝次关键数量
// - 保持统计信息尺寸稳定
struct MerchantLitterCountCell: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1) {
            Text(value)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
