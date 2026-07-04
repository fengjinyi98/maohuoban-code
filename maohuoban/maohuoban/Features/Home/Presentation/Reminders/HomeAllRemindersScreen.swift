import SwiftUI
import MaohuobanDesignSystem

// HomeAllRemindersScreen 全部提醒页
// 核心职责：
// - 展示首页同源提醒列表的完整集合
// - 点击提醒后复用首页提醒路由解析进入业务详情
struct HomeAllRemindersScreen: View {
    let reminders: [HomeDashboardSnapshot.Reminder]
    let routingContext: HomeActionRoutingContext
    let onOpenRoute: (HomeRoute) -> Void

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                if reminders.isEmpty {
                    HomeAllRemindersEmptyState()
                } else {
                    ForEach(reminders) { reminder in
                        Button {
                            if let route = HomeReminderRouteResolver.route(for: reminder, context: routingContext) {
                                onOpenRoute(route)
                            }
                        } label: {
                            HomeAllReminderRow(reminder: reminder)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s5)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("全部提醒")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("home.allReminders")
    }
}
