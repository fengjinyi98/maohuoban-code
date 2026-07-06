import SwiftUI
import MaohuobanDesignSystem

// HospitalBookingIntroSection 医院预约头部说明
// 核心职责：
// - 展示开发验证阶段合作医院入口
// - 说明预约会进入合作 HIS 闭环
struct HospitalBookingIntroSection: View {
    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "stethoscope")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("毛伙伴验证闭环医院")
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text("这些医院已接入毛伙伴 HIS，可接收诊前资料包并支持病历回流")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}
