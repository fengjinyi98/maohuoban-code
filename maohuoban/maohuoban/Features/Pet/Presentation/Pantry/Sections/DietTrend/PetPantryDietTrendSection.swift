import SwiftUI
import MaohuobanDesignSystem

// PetPantryDietTrendSection 储物柜饮食趋势区
// 核心职责：
// - 展示宠物近期饮食品类占比总览
// - 通过系统弹窗展示后端返回的趋势说明
struct PetPantryDietTrendSection: View {
    let petName: String
    let summary: PetDietTrendSummary

    @State private var isExplanationPresented = false

    private var presentation: PetPantryDietTrendPresentation {
        PetPantryDietTrendPresentation(summary: summary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            PetPantryDietTrendHeader(
                petName: petName,
                windowText: presentation.windowText,
                confidenceText: presentation.confidenceText,
                onShowExplanation: {
                    isExplanationPresented = true
                }
            )

            PetPantryDietTrendSegmentBar(segments: presentation.segmentItems)

            if presentation.isEmpty {
                Text("继续记录喂食后生成饮食趋势")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, MHBTheme.Spacing.s2)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4),
                        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4)
                    ],
                    spacing: MHBTheme.Spacing.s3
                ) {
                    ForEach(presentation.segmentItems) { segment in
                        PetPantryDietTrendLegendRow(segment: segment)
                    }
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
        .alert(presentation.explanationTitle, isPresented: $isExplanationPresented) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(presentation.explanationBody)
        }
    }
}
