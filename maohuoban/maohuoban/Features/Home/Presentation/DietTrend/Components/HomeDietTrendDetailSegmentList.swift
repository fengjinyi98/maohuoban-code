import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendDetailSegmentList 饮食趋势详情分段列表
// 核心职责：
// - 展示每个饮食品类的占比
// - 保持详情页与首页摘要使用同一展示模型
struct HomeDietTrendDetailSegmentList: View {
    let segments: [HomeDietTrendSegmentPresentation]

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            ForEach(segments) { segment in
                HStack(spacing: MHBTheme.Spacing.s3) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 8, height: 8)

                    Text(segment.title)
                        .font(MHBTheme.Typography.callout.weight(.medium))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Spacer()

                    Text(segment.percentageText)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
            }
        }
    }
}
