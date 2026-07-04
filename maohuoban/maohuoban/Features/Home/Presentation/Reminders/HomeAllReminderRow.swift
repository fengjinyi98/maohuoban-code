import SwiftUI
import MaohuobanDesignSystem

// HomeAllReminderRow 全部提醒行
// 核心职责：
// - 展示单条提醒标题、日期和到期状态
// - 保持全部页与首页提醒入口语义一致
struct HomeAllReminderRow: View {
    let reminder: HomeDashboardSnapshot.Reminder

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(reminder.title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(reminder.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text(reminder.dueText)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }

    private var iconName: String {
        switch reminder.kind {
        case .vaccine:
            "syringe"
        case .deworming:
            "shield.lefthalf.filled"
        case .followUp:
            "stethoscope"
        default:
            "bell.fill"
        }
    }

    private var iconColor: Color {
        switch reminder.kind {
        case .deworming:
            MHBTheme.ColorToken.success.color
        case .followUp:
            MHBTheme.ColorToken.teal.color
        default:
            MHBTheme.ColorToken.primary.color
        }
    }
}
