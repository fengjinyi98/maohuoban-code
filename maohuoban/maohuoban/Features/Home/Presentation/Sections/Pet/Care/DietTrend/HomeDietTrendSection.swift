import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendSection 首页饮食趋势模块
// 核心职责：
// - 在首页储物柜入口前展示当前宠物整体饮食趋势摘要
// - 通过系统导航进入趋势详情页
struct HomeDietTrendSection: View {
    let summary: PetDietTrendSummary
    let route: HomeRoute

    private var presentation: HomeDietTrendPresentation {
        HomeDietTrendPresentation(summary: summary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("饮食趋势")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    Text("\(presentation.windowText) · \(presentation.statusText)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                }

                Spacer()

                NavigationLink(value: route) {
                    HStack(spacing: 4) {
                        Text("查看")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.dietTrend.header")
            }

            HomeDietTrendSegmentBar(segments: presentation.activeSegments)

            HStack(spacing: MHBTheme.Spacing.s3) {
                if presentation.isEmpty {
                    Text("继续记录喂食后生成可参考趋势")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.56))
                } else {
                    ForEach(presentation.activeSegments.prefix(3)) { segment in
                        HomeDietTrendLegendItem(segment: segment)
                    }
                }

                Spacer(minLength: MHBTheme.Spacing.s2)

                Text(presentation.confidenceText)
                    .font(MHBTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.dietTrendSection")
    }
}
