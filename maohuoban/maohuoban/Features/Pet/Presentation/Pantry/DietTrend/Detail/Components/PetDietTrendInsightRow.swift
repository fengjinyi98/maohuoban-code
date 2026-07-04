import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendInsightRow 饮食趋势观察行
// 核心职责：
// - 展示单条后端分析观察
// - 统一趋势详情页的结论列表样式
struct PetDietTrendInsightRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.success.color)
                .padding(.top, 2)

            Text(text)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
