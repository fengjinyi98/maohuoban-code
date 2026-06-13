import SwiftUI
import MaohuobanDesignSystem

// HospitalBookingIntroSection 医院预约头部说明
// 核心职责：
// - 展示当前预约城市
// - 说明预约会绑定当前宠物档案
struct HospitalBookingIntroSection: View {
    let city: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "stethoscope")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("\(city)医院预约")
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text("预约结果会关联当前宠物，后续就诊记录可回流到时间线")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}
