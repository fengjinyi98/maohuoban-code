import SwiftUI
import MaohuobanDesignSystem

// SettingsSection 设置页分组容器
// 核心职责：
// - 提供设置列表统一卡片背景与圆角
// - 承载行组件并保持视觉分组一致
struct SettingsSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
    }
}

// SettingsSectionHeader 设置页分组标题
// 核心职责：
// - 为隐私与通用设置等页面提供小标题
// - 保持分组标题的字号和层级一致
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MHBTheme.Typography.section)
            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            .padding(.leading, MHBTheme.Spacing.s2)
    }
}

// SettingsDivider 设置页分割线
// 核心职责：
// - 提供行间统一分隔样式
// - 支持带图标行的缩进分隔
struct SettingsDivider: View {
    var leading: CGFloat = MHBTheme.Spacing.s4

    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separator.color)
            .frame(height: 1)
            .padding(.leading, leading)
    }
}

// SettingsRow 设置页导航行
// 核心职责：
// - 展示标题、图标、右侧状态和进入箭头
// - 将点击事件限定在明确行级入口
struct SettingsRow<Icon: View>: View {
    let title: String
    var value: String?
    var subtitle: String?
    var showChevron = true
    var alignment: SettingsRowAlignment = .leading
    let icon: Icon?
    let action: (() -> Void)?

    init(
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        showChevron: Bool = true,
        alignment: SettingsRowAlignment = .leading,
        action: (() -> Void)? = nil
    ) where Icon == EmptyView {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.showChevron = showChevron
        self.alignment = alignment
        self.icon = nil
        self.action = action
    }

    init(
        systemImage: String,
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        showChevron: Bool = true,
        action: (() -> Void)? = nil
    ) where Icon == Image {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.showChevron = showChevron
        self.alignment = .leading
        self.icon = Image(systemName: systemImage)
        self.action = action
    }

    var body: some View {
        Button(action: { action?() }) {
            if alignment == .center {
                Text(title)
                    .font(MHBTheme.Typography.body)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(.rect)
            } else {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    if let icon {
                        icon
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .frame(width: 24)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(MHBTheme.Typography.body)
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        if let subtitle {
                            Text(subtitle)
                                .font(MHBTheme.Typography.caption)
                                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: MHBTheme.Spacing.s2)

                    if let value {
                        Text(value)
                            .font(MHBTheme.Typography.callout)
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }

                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.vertical, MHBTheme.Spacing.s3)
                .frame(minHeight: 52)
                .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
    }
}

// SettingsToggleRow 设置页开关行
// 核心职责：
// - 展示设置项标题、副标题和开关
// - 将二元状态变更限制在绑定值上
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MHBTheme.Typography.body)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                if let subtitle {
                    Text(subtitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: MHBTheme.Spacing.s2)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(MHBTheme.ColorToken.primary.color)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .frame(minHeight: 52)
    }
}

// SettingsOptionRow 设置页单选行
// 核心职责：
// - 展示选项标题、说明和选中状态
// - 承载隐私范围与深色模式等单选交互
struct SettingsOptionRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MHBTheme.Typography.body)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    if let subtitle {
                        Text(subtitle)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelQuaternary.color)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s3)
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

enum SettingsRowAlignment {
    case leading
    case center
}
