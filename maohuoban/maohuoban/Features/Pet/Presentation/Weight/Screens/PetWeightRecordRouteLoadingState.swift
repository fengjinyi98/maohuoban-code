import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordRouteLoadingState 体重记录路由加载态
// 核心职责：
// - 在首页时间线进入单条体重记录时展示加载反馈
// - 避免数据加载前误展示记录缺失状态
struct PetWeightRecordRouteLoadingState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()

            Text("正在加载体重记录")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("体重记录详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
