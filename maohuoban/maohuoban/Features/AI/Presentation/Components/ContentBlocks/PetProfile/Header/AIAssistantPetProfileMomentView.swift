import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileMomentView 宠物档案时间文案项
// 核心职责：
// - 同时展示确定日期、确定性计算结果和 LLM 文案
// - 防止情感表达覆盖事实值
struct AIAssistantPetProfileMomentView: View {
    let label: String
    let dateText: String
    let metricText: String?
    let narrativeText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Text(label)
                    .font(MHBTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                Text(dateText)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .monospacedDigit()
                if let metricText, metricText.isEmpty == false {
                    Text(metricText)
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
            }

            if let narrativeText, narrativeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(narrativeText)
                    .font(MHBTheme.Typography.callout.weight(.regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
