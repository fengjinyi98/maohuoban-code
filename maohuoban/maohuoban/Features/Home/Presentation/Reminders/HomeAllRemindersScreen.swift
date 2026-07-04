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
    @State private var isAddReminderPresented = false

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    if reminders.isEmpty {
                        HomeAllRemindersEmptyState {
                            isAddReminderPresented = true
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: max(proxy.size.height - bottomInset, 360),
                            alignment: .center
                        )
                    } else {
                        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
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
                        .padding(.horizontal, MHBTheme.Spacing.s5)
                        .padding(.top, MHBTheme.Spacing.s5)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                if !reminders.isEmpty {
                    MHBBottomFloatingActionCTA(
                        title: "添加提醒",
                        systemImage: "plus",
                        bottomInset: bottomInset,
                        action: {
                            isAddReminderPresented = true
                        }
                    )
                    .zIndex(2)
                }
            }
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("全部提醒")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddReminderPresented) {
            HomeAddReminderSheet(context: routingContext)
        }
        .accessibilityIdentifier("home.allReminders")
    }
}
