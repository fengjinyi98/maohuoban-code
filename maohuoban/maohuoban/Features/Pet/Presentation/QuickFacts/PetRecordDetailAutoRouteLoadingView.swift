import SwiftUI
import MaohuobanDesignSystem

// PetRecordDetailAutoRouteLoadingView 自动分发加载态
// 核心职责：
// - 展示引用详情跳转时的轻量加载反馈
// - 避免空白页等待事件详情接口
struct PetRecordDetailAutoRouteLoadingView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            ProgressView()
            Text("正在打开记录")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .accessibilityIdentifier("pet.recordDetail.auto.loading")
    }
}
