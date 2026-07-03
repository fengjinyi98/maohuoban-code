import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordRouteErrorState 体重记录路由错误态
// 核心职责：
// - 展示单条体重记录加载失败原因
// - 提供可恢复的重新加载入口
struct PetWeightRecordRouteErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)

            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MHBTheme.Spacing.s6)

            Button("重新加载", action: retry)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .frame(height: 44)
                .background(MHBTheme.ColorToken.primary.color, in: Capsule())
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("体重记录详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
