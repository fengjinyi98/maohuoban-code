import SwiftUI
import MaohuobanDesignSystem

// HomeRemindersSection 近期提醒模块
// 核心职责：
// - 采用垂直列表形式平铺展示近期提醒（疫苗、驱虫、体检等）
// - 整体视觉与大底融合，对齐“艺人代表作”纯扁平设计
struct HomeRemindersSection: View {
    let reminders: [HomeDashboardSnapshot.Reminder]
    let routingContext: HomeActionRoutingContext
    let onOpenAddReminder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // 头部 (对齐时间线样式)
            HStack {
                Text("近期提醒")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                NavigationLink(value: HomeRoute.allReminders(reminders: reminders, context: routingContext)) {
                    HStack(spacing: 4) {
                        Text("查看全部")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .buttonStyle(.plain)
            }

            if visibleReminders.isEmpty {
                Button(action: onOpenAddReminder) {
                    HomeReminderEmptyState()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.reminders.emptyState")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleReminders.enumerated()), id: \.element.id) { index, reminder in
                        let isFirst = index == 0
                        if let route = HomeReminderRouteResolver.route(for: reminder, context: routingContext) {
                            NavigationLink(value: route) {
                                HomeReminderListRow(reminder: reminder, isFirst: isFirst)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.reminder.\(reminder.id)")
                        } else {
                            HomeReminderListRow(reminder: reminder, isFirst: isFirst)
                                .accessibilityIdentifier("home.reminder.\(reminder.id).disabled")
                        }

                        if index < visibleReminders.count - 1 {
                            HStack(spacing: 0) {
                                Spacer()
                                    .frame(width: 88)
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 0.5)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.remindersSection")
    }

    private var visibleReminders: [HomeDashboardSnapshot.Reminder] {
        Array(reminders.prefix(3))
    }
}

// HomeReminderEmptyState 近期提醒空状态
// 核心职责：
// - 与首页相册和储物柜空态保持同一虚线框布局
// - 整块区域作为添加提醒入口的点击目标
private struct HomeReminderEmptyState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "bell.badge")
                .font(.system(size: 24))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Text("添加第一个提醒")
                .font(MHBTheme.Typography.callout.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MHBTheme.Spacing.s6)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(MHBTheme.ColorToken.separator.color)
        )
        .contentShape(Rectangle())
    }
}

// HomeReminderListRow 垂直列表单行组件
private struct HomeReminderListRow: View {
    let reminder: HomeDashboardSnapshot.Reminder
    let isFirst: Bool

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
            // 左侧：72x72 的大图标方形卡片 (模仿唱片封面图样式)
            iconView
                .frame(width: 72, height: 72)
                .background(iconBgColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 右侧：多行文本信息与右侧箭头组合
            VStack(alignment: .leading, spacing: 3) {
                // 第一行：事件名称
                Text(reminder.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                // 第二行：日期
                Text(reminder.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))

                // 第三行：备注（仅当有备注内容时才显示）
                if let remarks = reminder.remarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }

                // 第四行：显示多少天后
                Text(reminder.dueText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(mhbHex: "F59E0B")) // 暖金/橘色强调
            }
            .layoutPriority(1)

            Spacer()

            // 右下指示箭头 (对齐代表作列表)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.top, isFirst ? 0 : MHBTheme.Spacing.s3)
        .padding(.bottom, MHBTheme.Spacing.s3)
        .contentShape(Rectangle())
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(iconFgColor)
    }

    private var iconName: String {
        switch reminder.kind {
        case .vaccine:
            return "syringe"
        case .deworming:
            return "ladybug"
        case .followUp:
            return "stethoscope"
        default:
            return "bell"
        }
    }

    private var iconFgColor: Color {
        switch reminder.kind {
        case .vaccine:
            return Color(mhbHex: "B794F4") // 紫色
        case .deworming:
            return Color(mhbHex: "A3E635") // 绿色
        case .followUp:
            return Color(mhbHex: "CBD5E0") // 浅灰
        default:
            return .white
        }
    }

    private var iconBgColor: Color {
        iconFgColor.opacity(0.12)
    }
}
