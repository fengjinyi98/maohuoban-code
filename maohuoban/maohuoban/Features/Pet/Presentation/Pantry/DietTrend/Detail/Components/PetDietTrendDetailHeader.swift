import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendDetailHeader 饮食趋势详情头部
// 核心职责：
// - 展示分析对象、窗口期和参考度
// - 提供趋势说明入口
struct PetDietTrendDetailHeader: View {
    let petName: String?
    let windowText: String
    let statusText: String
    let confidenceText: String
    let onShowExplanation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(petName.map { "\($0)的饮食趋势" } ?? "饮食趋势")
                        .font(MHBTheme.Typography.title)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    HStack(spacing: MHBTheme.Spacing.s2) {
                        Text(windowText)
                            .font(MHBTheme.Typography.caption.weight(.medium))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MHBTheme.ColorToken.separatorSoft.color)
                            .clipShape(Capsule())

                        Text(statusText)
                            .font(MHBTheme.Typography.caption.weight(.medium))
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                            .clipShape(Capsule())

                        Text(confidenceText)
                            .font(MHBTheme.Typography.caption.weight(.medium))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    }
                }

                Spacer()

                Button(action: onShowExplanation) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看饮食趋势说明")
            }
        }
    }
}
