import SwiftUI
import MaohuobanDesignSystem

// PublishConfigurationSection 发布配置区
// 核心职责：
// - 展示宠物、事件类型、地点和可见范围配置入口
// - 将配置选择事件交回发布页状态源
struct PublishConfigurationSection: View {
    let selectedPetName: String?
    let eventType: PublishEventType
    let locationTitle: String?
    let visibility: PublishVisibility
    let onSelectPet: () -> Void
    let onSelectEventType: () -> Void
    let onSelectLocation: () -> Void
    let onSelectVisibility: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            PublishSectionHeader(
                title: "发布设置",
                subtitle: "每条内容都围绕宠物事件沉淀"
            )

            PublishConfigurationRow(
                systemImage: "pawprint.fill",
                iconColor: MHBTheme.ColorToken.primary.color,
                title: selectedPetName ?? "关联宠物",
                subtitle: selectedPetName == nil ? "发布前必须选择" : "将进入这只宠物的时间线",
                action: onSelectPet
            )

            PublishConfigurationRow(
                systemImage: eventType.systemImage,
                iconColor: MHBTheme.ColorToken.success.color,
                title: eventType.title,
                subtitle: eventType.subtitle,
                action: onSelectEventType
            )

            PublishConfigurationRow(
                systemImage: "mappin.and.ellipse",
                iconColor: MHBTheme.ColorToken.warning.color,
                title: locationTitle ?? "标记地点",
                subtitle: locationTitle == nil ? "同城内容可回流实体页" : "地点会作为推荐信号",
                action: onSelectLocation
            )

            PublishConfigurationRow(
                systemImage: visibility.systemImage,
                iconColor: MHBTheme.ColorToken.purple.color,
                title: visibility.title,
                subtitle: visibility.subtitle,
                action: onSelectVisibility
            )
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .accessibilityIdentifier("publish.configuration.section")
    }
}

// PublishConfigurationRow 发布配置行
// 核心职责：
// - 统一渲染发布页配置项样式
// - 提供明确触达区域和导航提示
private struct PublishConfigurationRow: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: systemImage)
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 30, height: 30)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(title)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(2)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)

                Image(systemName: "chevron.right")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(.vertical, MHBTheme.Spacing.s2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
