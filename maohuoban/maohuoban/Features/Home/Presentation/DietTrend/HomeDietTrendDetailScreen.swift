import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendDetailScreen 饮食趋势详情页
// 核心职责：
// - 展示当前宠物整体饮食趋势分析摘要
// - 承载后续 HIS 参考摘要和长期趋势扩展入口
struct HomeDietTrendDetailScreen: View {
    let petName: String?
    let summary: PetDietTrendSummary

    @State private var isExplanationPresented = false

    private var presentation: HomeDietTrendPresentation {
        HomeDietTrendPresentation(summary: summary)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                HomeDietTrendDetailHeader(
                    petName: petName,
                    windowText: presentation.windowText,
                    statusText: presentation.statusText,
                    confidenceText: presentation.confidenceText,
                    onShowExplanation: {
                        isExplanationPresented = true
                    }
                )

                HomeDietTrendSegmentBar(segments: presentation.activeSegments)
                    .frame(height: 10)

                HomeDietTrendDetailSegmentList(segments: presentation.segments)

                HomeDietTrendDetailReferenceSection()
            }
            .padding(MHBTheme.Spacing.s5)
        }
        .navigationTitle("饮食趋势")
        .navigationBarTitleDisplayMode(.inline)
        .alert(presentation.explanationTitle, isPresented: $isExplanationPresented) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(presentation.explanationBody)
        }
    }
}
