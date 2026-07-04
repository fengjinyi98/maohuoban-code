import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDetailErrorView 疫苗驱虫详情错误态
// 核心职责：
// - 展示真实详情加载失败原因
// - 阻止页面回落到 mock 记录
struct PetPreventiveCareRecordDetailErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s8)
    }
}
