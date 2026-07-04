import SwiftUI
import MaohuobanDesignSystem

// HomeAllRemindersEmptyState 全部提醒空态
// 核心职责：
// - 参考储物柜页面级空态提供居中引导
// - 承载添加第一个提醒的主操作入口
struct HomeAllRemindersEmptyState: View {
    let onAddReminder: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "bell.badge")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            VStack(spacing: MHBTheme.Spacing.s2) {
                Text("还没有提醒")
                    .font(MHBTheme.Typography.headline.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .multilineTextAlignment(.center)

                Text("添加疫苗、驱虫、复诊或自定义提醒后，会在这里集中查看。")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onAddReminder) {
                Label("添加第一个提醒", systemImage: "plus")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .frame(height: 44)
                    .background(MHBTheme.ColorToken.primary.color, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .accessibilityIdentifier("home.allReminders.emptyState")
    }
}
