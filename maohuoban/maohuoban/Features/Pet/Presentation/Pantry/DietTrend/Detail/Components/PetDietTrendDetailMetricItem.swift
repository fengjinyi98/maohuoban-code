import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendDetailMetricItem 饮食趋势详情指标项
// 核心职责：
// - 承载单个分析指标标题和值
// - 保持指标布局在横向和纵向容器中复用
struct PetDietTrendDetailMetricItem: View {
    let title: String
    let value: String
    var icon: String? = nil
    var iconColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor ?? MHBTheme.ColorToken.labelSecondary.color)
                }
                Text(title)
                    .font(MHBTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Text(value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

