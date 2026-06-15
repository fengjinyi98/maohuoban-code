import SwiftUI
import MaohuobanDesignSystem

// HomeRemindersSection 近期提醒模块
// 核心职责：
// - 采用垂直列表形式平铺展示近期提醒（疫苗、驱虫、体检等）
// - 整体视觉与大底融合，对齐“艺人代表作”纯扁平设计
struct HomeRemindersSection: View {
    let reminders: [HomeDashboardSnapshot.Reminder]
    let routingContext: HomeActionRoutingContext

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // 头部 (对齐时间线样式)
            HStack {
                Text("近期提醒")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 4) {
                    Text("查看全部")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, MHBTheme.Spacing.s2)

            // 垂直扁平列表
            VStack(spacing: 0) {
                ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                    if let route = HomeReminderRouteResolver.route(for: reminder, context: routingContext) {
                        NavigationLink(value: route) {
                            HomeReminderListRow(reminder: reminder)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.reminder.\(reminder.id)")
                    } else {
                        HomeReminderListRow(reminder: reminder)
                            .accessibilityIdentifier("home.reminder.\(reminder.id).disabled")
                    }

                    // 绘制细分底线，起始点对齐右侧文本开头（偏移 88pt）
                    if index < reminders.count - 1 {
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.remindersSection")
    }
}

// HomeReminderListRow 垂直列表单行组件
private struct HomeReminderListRow: View {
    let reminder: HomeDashboardSnapshot.Reminder

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
                    .foregroundStyle(Color(hex: "F59E0B")) // 暖金/橘色强调
            }
            .layoutPriority(1)

            Spacer()

            // 右下指示箭头 (对齐代表作列表)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
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
            return Color(hex: "B794F4") // 紫色
        case .deworming:
            return Color(hex: "A3E635") // 绿色
        case .followUp:
            return Color(hex: "CBD5E0") // 浅灰
        default:
            return .white
        }
    }

    private var iconBgColor: Color {
        iconFgColor.opacity(0.12)
    }
}

// 辅助 Color 的 Hex 初始化扩展
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
