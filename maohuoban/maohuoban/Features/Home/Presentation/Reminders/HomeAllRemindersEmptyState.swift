import SwiftUI
import MaohuobanDesignSystem

// HomeAllRemindersEmptyState 全部提醒空态
// 核心职责：
// - 展示当前宠物暂无提醒状态
// - 避免空页面被误认为加载失败
struct HomeAllRemindersEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("暂无提醒")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text("新增疫苗、驱虫或复诊记录后，带下次时间的记录会出现在这里。")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}
