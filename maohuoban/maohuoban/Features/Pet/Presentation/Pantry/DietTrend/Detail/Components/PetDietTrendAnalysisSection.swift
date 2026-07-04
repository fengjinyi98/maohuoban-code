import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendAnalysisSection 饮食趋势分析结论区
// 核心职责：
// - 展示后端生成的用户可读趋势结论
// - 避免页面暴露算法中间指标
struct PetDietTrendAnalysisSection: View {
    let headline: String
    let summaryText: String
    let observations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(headline)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text(summaryText)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                ForEach(observations, id: \.self) { observation in
                    PetDietTrendInsightRow(text: observation)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
