import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDetailLoadingView 疫苗驱虫详情加载态
// 核心职责：
// - 展示事件详情请求反馈
// - 避免使用演示数据填充详情
struct PetPreventiveCareRecordDetailLoadingView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载记录详情")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s8)
    }
}
