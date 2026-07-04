import SwiftUI
import MaohuobanDesignSystem

// PetPantryDietTrendHeader 饮食趋势头部
// 核心职责：
// - 展示趋势标题、统计窗口和置信度摘要
// - 承载趋势说明弹窗入口
struct PetPantryDietTrendHeader: View {
    let petName: String
    let windowText: String
    let confidenceText: String
    let onShowExplanation: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text("饮食趋势")
                        .font(MHBTheme.Typography.headline.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(windowText)
                        .font(MHBTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s2)
                        .padding(.vertical, MHBTheme.Spacing.s1)
                        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                        .clipShape(Capsule())
                }

                Text("\(petName)近期喂食结构 · \(confidenceText)")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                onShowExplanation()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }
}
