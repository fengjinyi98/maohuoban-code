import SwiftUI
import MaohuobanDesignSystem

// SettingsOfficialVerificationScreen 官方认证页面
// 核心职责：
// - 展示个人职业、机构和企业认证入口
// - 保持官方认证页面的分流布局
struct SettingsOfficialVerificationScreen: View {
    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsVerificationCard(title: "个人职业认证", subtitle: "医生、训练师、救助人等职业资质认证", systemImage: "person.badge.shield.checkmark")
                SettingsVerificationCard(title: "机构认证", subtitle: "宠物医院、救助站、门店等机构主体认证", systemImage: "building.2")
                SettingsVerificationCard(title: "企业认证", subtitle: "品牌、供应链和服务商企业认证", systemImage: "briefcase")
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("官方认证")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// SettingsVerificationCard 认证入口卡片
// 核心职责：
// - 展示单个认证类型的图标、标题和描述
// - 使用背景色和圆角匹配设置页面风格
struct SettingsVerificationCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            Spacer()
        }
        .padding(MHBTheme.Spacing.s5)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(.rect(cornerRadius: MHBTheme.Radius.extraLarge))
    }
}
