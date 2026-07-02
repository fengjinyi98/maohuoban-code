import SwiftUI
import MaohuobanDesignSystem

// PublishConfigurationIcon 发布配置行图标来源
// 核心职责：
// - 区分系统 SF Symbol 和项目资产图标
// - 为发布配置行提供统一的图标渲染入口
enum PublishConfigurationIcon {
    case system(String)
    case asset(String)
}

// PublishConfigurationRow 小红书风格配置行
// 核心职责：
// - 渲染发布页配置入口的图标、标题和值
// - 承载点击后打开对应配置弹层的入口
struct PublishConfigurationRow: View {
    let icon: PublishConfigurationIcon
    let iconColor: Color
    let title: String
    let value: String?
    let action: () -> Void

    init(
        iconName: String,
        iconColor: Color,
        title: String,
        value: String?,
        action: @escaping () -> Void
    ) {
        self.icon = .system(iconName)
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.action = action
    }

    init(
        assetIconName: String,
        iconColor: Color,
        title: String,
        value: String?,
        action: @escaping () -> Void
    ) {
        self.icon = .asset(assetIconName)
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                PublishConfigurationIconView(icon: icon, color: iconColor)

                Text(title)
                    .font(MHBTheme.Typography.body.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer()

                if let value {
                    Text(value)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// PublishConfigurationIconView 发布配置行图标视图
// 核心职责：
// - 根据图标来源渲染统一尺寸的行内图标
// - 保持资产图标和系统图标的主题色一致
struct PublishConfigurationIconView: View {
    let icon: PublishConfigurationIcon
    let color: Color

    var body: some View {
        ZStack {
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(color)
            case .asset(let name):
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .frame(width: MHBTheme.IconSize.small, height: MHBTheme.IconSize.small)
            }
        }
        .frame(width: 24, height: 24)
    }
}
