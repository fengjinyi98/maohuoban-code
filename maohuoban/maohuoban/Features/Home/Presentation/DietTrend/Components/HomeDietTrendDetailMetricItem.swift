import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendDetailMetricItem 饮食趋势详情指标项
// 核心职责：
// - 承载单个分析指标标题和值
// - 保持指标布局在横向和纵向容器中复用
struct HomeDietTrendDetailMetricItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(title)
                .font(MHBTheme.Typography.caption.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Text(value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

