import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendDetailReferenceSection 饮食趋势参考说明区
// 核心职责：
// - 表达趋势数据的产品边界
// - 为后续 HIS 参考摘要扩展预留位置
struct HomeDietTrendDetailReferenceSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("就诊参考")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("这里会逐步沉淀长期喂食结构、食欲波动和异常记录对照，作为就诊沟通参考。")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}
