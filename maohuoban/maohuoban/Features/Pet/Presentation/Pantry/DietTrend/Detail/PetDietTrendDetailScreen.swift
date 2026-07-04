import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendDetailScreen 饮食趋势详情页
// 核心职责：
// - 展示当前宠物整体饮食趋势分析摘要
// - 展示后端返回的样本、基线和库存校准状态
struct PetDietTrendDetailScreen: View {
    let petName: String?
    let summary: PetDietTrendSummary

    @State private var isExplanationPresented = false

    private var presentation: PetDietTrendPresentation {
        PetDietTrendPresentation(summary: summary)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetDietTrendDetailHeader(
                    petName: petName,
                    windowText: presentation.windowText,
                    statusText: presentation.statusText,
                    confidenceText: presentation.confidenceText,
                    onShowExplanation: {
                        isExplanationPresented = true
                    }
                )

                PetDietTrendSegmentBar(segments: presentation.activeSegments)
                    .frame(height: 10)

                PetDietTrendDetailSegmentList(segments: presentation.segments)

                PetDietTrendAnalysisSection(
                    headline: presentation.headline,
                    summaryText: presentation.summaryText,
                    observations: presentation.observations
                )

                PetDietTrendDetailMetricGrid(presentation: presentation)

                PetDietTrendDetailEvidenceSection(presentation: presentation)
            }
            .padding(MHBTheme.Spacing.s5)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("饮食趋势")
        .navigationBarTitleDisplayMode(.inline)
        .alert(presentation.explanationTitle, isPresented: $isExplanationPresented) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(presentation.explanationBody)
        }
    }
}
