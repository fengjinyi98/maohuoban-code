import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendDetailEvidenceSection 饮食趋势证据说明区
// 核心职责：
// - 展示后端返回的参考度依据
// - 展示异常和就医期样本排除结果
struct HomeDietTrendDetailEvidenceSection: View {
    let presentation: HomeDietTrendPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("数据依据")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                HomeDietTrendDetailEvidenceRow(text: presentation.excludedSampleText)

                ForEach(presentation.confidenceBasis, id: \.self) { item in
                    HomeDietTrendDetailEvidenceRow(text: item)
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

